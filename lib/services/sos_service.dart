import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SosService {
  // ── Test overrides ────────────────────────────────────────────────────────

  /// Replaces the Supabase Edge Function call in tests.
  static Future<Map<String, dynamic>> Function(List<String>, String)?
      _edgeFunctionOverride;

  /// Replaces SupabaseService.getGuardianOneSignalIds() in tests.
  static Future<List<String>> Function(List<String>)? _getOneSignalIdsOverride;

  @visibleForTesting
  static void setEdgeFunctionOverride(
    Future<Map<String, dynamic>> Function(List<String>, String)? fn,
  ) {
    _edgeFunctionOverride = fn;
  }

  @visibleForTesting
  static void setGetOneSignalIdsOverride(
    Future<List<String>> Function(List<String>)? fn,
  ) {
    _getOneSignalIdsOverride = fn;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Отправка SOS всем хранителям.
  static Future<Map<String, dynamic>> sendSOS() async {
    try {
      // 1. Получаем свой user_id и имя (FR-20)
      final myUserId = await UserService.getUserId();
      final userName = await UserService.getUserName();

      // 2. Читаем guardian IDs из SharedPreferences
      final guardianUserIds = await _getGuardianUserIds();

      if (guardianUserIds.isEmpty) {
        return {'success': false, 'error': 'No guardians configured'};
      }

      // 3. Получаем OneSignal IDs хранителей из Supabase
      final oneSignalIds = _getOneSignalIdsOverride != null
          ? await _getOneSignalIdsOverride!(guardianUserIds)
          : await SupabaseService.getGuardianOneSignalIds(guardianUserIds);

      if (oneSignalIds.isEmpty) {
        return {
          'success': false,
          'error':
              'No active guardians found. Make sure they have the app installed.',
        };
      }

      // 4. Формируем сообщение (FR-20, AC-14, AC-15)
      final message = (userName != null && userName.isNotEmpty)
          ? 'SOS Emergency from $userName ($myUserId)'
          : 'SOS Emergency from $myUserId';

      // 5. Вызываем Edge Function
      final result = _edgeFunctionOverride != null
          ? await _edgeFunctionOverride!(oneSignalIds, message)
          : await _callEdgeFunction(oneSignalIds, message);

      return result['success'] == true
          ? {'success': true, 'recipients': oneSignalIds.length}
          : {'success': false, 'error': result['error'] ?? 'Unknown error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _callEdgeFunction(
    List<String> playerIds,
    String message,
  ) async {
    final response = await Supabase.instance.client.functions
        .invoke(
          'send-sos',
          body: {'player_ids': playerIds, 'message': message},
        )
        .timeout(const Duration(seconds: 10));
    if (response.data is! Map) {
      return {'success': false, 'error': 'Invalid response from server'};
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<List<String>> _getGuardianUserIds() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> guardians = [];
    for (int i = 1; i <= 5; i++) {
      final id = prefs.getString('guardian$i');
      if (id != null && id.isNotEmpty) guardians.add(id);
    }
    return guardians;
  }
}
