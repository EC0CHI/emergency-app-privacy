import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/id_generator.dart';

class UserService {
  static const String _userIdKey = 'myUserId';
  static const String _userNameKey = 'user_name';

  // Override для тестов: заменяет вызов Supabase при сохранении имени
  static Future<void> Function(String userId, String name)? _supabaseSaveOverride;

  @visibleForTesting
  static void setSupabaseSaveOverride(
    Future<void> Function(String userId, String name)? fn,
  ) => _supabaseSaveOverride = fn;

  /// Получить ID пользователя (создать если не существует)
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);

    if (userId == null || userId.isEmpty) {
      userId = IdGenerator.generate();
      await prefs.setString(_userIdKey, userId);
    }

    return userId;
  }

  /// Проверить существует ли ID
  static Future<bool> hasUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    return id != null && id.isNotEmpty;
  }

  /// Проверить установлено ли имя пользователя (FR-01)
  static Future<bool> hasUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_userNameKey);
    return name != null && name.isNotEmpty;
  }

  /// Получить имя пользователя из SharedPreferences (FR-02)
  /// Возвращает null если имя не установлено или пустая строка
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_userNameKey);
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Сохранить имя пользователя локально и в Supabase (FR-03)
  ///
  /// NFR-06: SharedPreferences сохраняется ДО вызова Supabase.
  /// При ошибке Supabase — локальное сохранение уже выполнено, исключение
  /// пробрасывается вызывающему коду для отображения Snackbar (EC-03).
  ///
  /// Выбрасывает [StateError] если userId не инициализирован.
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);

    if (userId == null || userId.isEmpty) {
      throw StateError(
        'Cannot save user name: userId not initialized. '
        'Call getUserId() before saveUserName().',
      );
    }

    // NFR-06: SharedPreferences сохраняется ПЕРВЫМ
    await prefs.setString(_userNameKey, name);

    // Supabase синхронизация (override в тестах, реальный вызов в production)
    final saveFn = _supabaseSaveOverride;
    if (saveFn != null) {
      await saveFn(userId, name);
    } else {
      try {
        await Supabase.instance.client
            .from('users')
            .upsert({'user_id': userId, 'user_name': name},onConflict: 'user_id');
        print('✅ Supabase upsert success');
      } catch (e) {
        print('❌ Supabase upsert error: $e');
        rethrow;
      }
    }
  }
}
