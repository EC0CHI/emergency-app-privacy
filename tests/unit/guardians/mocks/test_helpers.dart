// ============================================================
// Общие тестовые хелперы для Guardians тестов
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/services/guardians_service.dart';

import 'mock_guardians_service.dart';

// ---------------------------------------------------------------------------
// Ключи виджетов GuardiansScreen (форма редактирования)
// ---------------------------------------------------------------------------
// Реализация GuardiansScreen ОБЯЗАНА использовать эти ключи.

/// ID-поле хранителя по слоту 1–5: Key('guardian_id_field_1') ... Key('guardian_id_field_5')
Key guardianIdFieldKey(int slot) => Key('guardian_id_field_$slot');

/// Nickname-поле хранителя по слоту 1–5
Key guardianNicknameFieldKey(int slot) => Key('guardian_nickname_field_$slot');

/// Виджет статуса поиска (текст "✓ Found: X" или "⚠️ User not found") по слоту
Key guardianSearchStatusKey(int slot) => Key('guardian_search_status_$slot');

/// Индикатор загрузки поиска по слоту
Key guardianSearchLoadingKey(int slot) => Key('guardian_search_loading_$slot');

/// Кнопка "Сохранить" на GuardiansScreen
const Key kGuardiansSaveButton = Key('guardians_save_button');

// ---------------------------------------------------------------------------
// Ключи виджетов списка хранителей (GuardianListWidget / GuardiansScreen list)
// ---------------------------------------------------------------------------

/// Элемент списка по слоту 1–5
Key guardianListItemKey(int slot) => Key('guardian_list_item_$slot');

/// Основной текст (имя / nickname / ID) в элементе списка
Key guardianListPrimaryTextKey(int slot) => Key('guardian_list_primary_$slot');

/// Вторичный текст (User ID, мелким шрифтом) в элементе списка
Key guardianListSecondaryTextKey(int slot) => Key('guardian_list_secondary_$slot');

/// Индикатор загрузки элемента списка (пока имя ещё загружается)
Key guardianListLoadingKey(int slot) => Key('guardian_list_loading_$slot');

// ---------------------------------------------------------------------------
// buildTestApp — минимальная обёртка с локализацией
// ---------------------------------------------------------------------------
Widget buildGuardiansTestApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

// ---------------------------------------------------------------------------
// Вспомогательные: инициализация SharedPreferences с данными хранителей
// ---------------------------------------------------------------------------

/// Установить данные хранителей в SharedPreferences.
/// [ids] — слот (1–5) → userId; [nicknames] — слот → nickname.
Future<void> setGuardianPrefs({
  Map<int, String> ids = const {},
  Map<int, String> nicknames = const {},
  String? myUserId,
}) async {
  final Map<String, Object> values = {};
  if (myUserId != null) values['myUserId'] = myUserId;
  for (final entry in ids.entries) {
    values['guardian${entry.key}'] = entry.value;
  }
  for (final entry in nicknames.entries) {
    values['guardian${entry.key}_nickname'] = entry.value;
  }
  SharedPreferences.setMockInitialValues(values);
}

// ---------------------------------------------------------------------------
// GuardiansService mock setup / teardown
// ---------------------------------------------------------------------------
MockGuardiansService? _activeMock;

MockGuardiansService setupGuardiansServiceMock() {
  final mock = MockGuardiansService();
  _activeMock = mock;
  GuardiansService.setFindUserNameOverride(mock.findUserName);
  return mock;
}

void teardownGuardiansServiceMock() {
  GuardiansService.setFindUserNameOverride(null);
  _activeMock?.reset();
  _activeMock = null;
}

// ---------------------------------------------------------------------------
// NavigatorObserver для проверки навигации
// ---------------------------------------------------------------------------
class TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  void reset() {
    pushedRoutes.clear();
    poppedRoutes.clear();
  }
}
