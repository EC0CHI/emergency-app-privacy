// ============================================================
// Тестовые хелперы для MainScreen тестов
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/screens/main_screen.dart';
import 'package:emergency_app/services/user_service.dart';

// ---------------------------------------------------------------------------
// Ключи виджетов — должны совпадать с реализацией MainScreen
// ---------------------------------------------------------------------------
// Реализация MainScreen ОБЯЗАНА использовать эти ключи.

/// Карточка "My ID" (Container / Card, весь блок)
const Key kMyIdCard = Key('my_id_card');

/// Текст имени пользователя над ID (виден только если имя установлено)
const Key kUserNameDisplay = Key('user_name_display');

/// Текст User ID в карточке
const Key kUserIdDisplay = Key('user_id_display');

/// Кнопка "Edit Name" в карточке
const Key kEditNameButton = Key('edit_name_button');

/// Диалог редактирования имени (root виджет AlertDialog или Dialog)
const Key kEditNameDialog = Key('edit_name_dialog');

/// TextField внутри диалога
const Key kEditNameField = Key('edit_name_field');

/// Кнопка подтверждения в диалоге ("Save" / "OK")
const Key kEditNameConfirmButton = Key('edit_name_confirm_button');

/// Кнопка отмены в диалоге ("Cancel")
const Key kEditNameCancelButton = Key('edit_name_cancel_button');

// ---------------------------------------------------------------------------
// buildMainScreenTestApp
// ---------------------------------------------------------------------------
// MainScreen не использует AppLocalizations (hardcoded strings),
// поэтому минимальной обёртки достаточно.
Widget buildMainScreenTestApp() {
  return MaterialApp(
    home: MainScreen(updateLocale: (_) {}), // 🔴 MainScreen из lib/screens/main_screen.dart
  );
}

// ---------------------------------------------------------------------------
// Инициализация SharedPreferences
// ---------------------------------------------------------------------------

/// Установить userId и опционально userName в SharedPreferences
Future<void> initMainScreenPrefs({
  required String userId,
  String? userName,
}) async {
  final Map<String, Object> values = {'myUserId': userId};
  if (userName != null && userName.isNotEmpty) {
    values['user_name'] = userName;
  }
  SharedPreferences.setMockInitialValues(values);
}

/// Установить только userId (без userName — первый запуск или legacy)
Future<void> initPrefsWithoutName({required String userId}) async {
  SharedPreferences.setMockInitialValues({'myUserId': userId});
}

// ---------------------------------------------------------------------------
// UserService Supabase mock setup / teardown
// ---------------------------------------------------------------------------
void setupUserServiceMock({
  Object? supabaseError,
  List<Map<String, String>>? capturedCalls,
}) {
  UserService.setSupabaseSaveOverride((userId, name) async {
    capturedCalls?.add({'userId': userId, 'name': name});
    if (supabaseError != null) throw supabaseError;
  });
}

void teardownUserServiceMock() {
  UserService.setSupabaseSaveOverride(null);
}
