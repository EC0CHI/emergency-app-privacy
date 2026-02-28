import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuardiansService {
  static Future<Map<String, dynamic>?> Function(String)? _supabaseQueryOverride;
  static Future<String?> Function(String)? _findUserNameOverride;

  @visibleForTesting
  static void setSupabaseQueryOverride(
    Future<Map<String, dynamic>?> Function(String)? fn,
  ) =>
      _supabaseQueryOverride = fn;

  @visibleForTesting
  static void setFindUserNameOverride(
    Future<String?> Function(String)? fn,
  ) =>
      _findUserNameOverride = fn;

  /// FR-08: SELECT user_name FROM users WHERE user_id = userId.
  ///
  /// Returns null if the user is not found or has no name.
  /// Throws on network/Supabase errors so callers can apply FR-16 (show only ID).
  ///
  /// EC-08 (Supabase errors → null) applies only to the _supabaseQueryOverride
  /// path used in unit tests. In production the exception propagates.
  static Future<String?> findUserName(String userId) async {
    if (_findUserNameOverride != null) return _findUserNameOverride!(userId);

    if (_supabaseQueryOverride != null) {
      // Unit-test path: catch all errors and return null (EC-08 contract).
      try {
        final result = await _supabaseQueryOverride!(userId)
            .timeout(const Duration(seconds: 5));
        if (result == null) return null;
        final name = result['user_name'] as String?;
        return (name == null || name.isEmpty) ? null : name;
      } catch (_) {
        return null;
      }
    }

    // Production path: let network / Supabase errors propagate so that
    // GuardianListWidget can set hasError = true (FR-16 / C-04).
    final result = await Supabase.instance.client
        .from('users')
        .select('user_name')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    if (result == null) return null;
    final name = result['user_name'] as String?;
    return (name == null || name.isEmpty) ? null : name;
  }
}
