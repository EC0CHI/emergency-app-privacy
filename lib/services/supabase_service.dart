import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Инициализация Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    print('Supabase initialized');
  }

  /// Сохранение или обновление пользователя
  static Future<void> saveUser(String userId, String? oneSignalId) async {
    try {
      // Проверяем существует ли пользователь
      final existing = await _client
          .from('users')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Создаем нового пользователя
        await _client.from('users').insert({
          'user_id': userId,
          'onesignal_id': oneSignalId,
          'last_seen': DateTime.now().toIso8601String(),
        });
        print('New user created: $userId');
      } else {
        // Обновляем существующего
        await _client.from('users').update({
          'onesignal_id': oneSignalId,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);
        print('User updated: $userId');
      }
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  /// Получение OneSignal IDs хранителей по их user_id
  static Future<List<String>> getGuardianOneSignalIds(
    List<String> guardianUserIds,
  ) async {
    if (guardianUserIds.isEmpty) return [];

    // Фильтруем пустые строки
    final validIds = guardianUserIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) return [];

    try {
      final response = await _client
          .from('users')
          .select('onesignal_id')
          .inFilter('user_id', validIds)
          .not('onesignal_id', 'is', null);

      if (response == null || response.isEmpty) {
        print('Guardians not found for: $validIds');
        return [];
      }

      final ids = (response as List)
          .map((e) => e['onesignal_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      print('Found ${ids.length} guardians out of ${validIds.length}');
      return ids;
    } catch (e) {
      print('Error fetching OneSignal IDs: $e');
      return [];
    }
  }

  /// Обновление времени последнего визита
  static Future<void> updateLastSeen(String userId) async {
    try {
      await _client.from('users').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      print('Error updating last_seen: $e');
    }
  }

  /// Проверка существования пользователя по user_id
  static Future<bool> userExists(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking user: $e');
      return false;
    }
  }
}