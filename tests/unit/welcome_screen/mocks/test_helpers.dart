// ============================================================
// Общие тестовые хелперы для WelcomeScreen / App Routing тестов
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/services/user_service.dart';

// ---------------------------------------------------------------------------
// Ключи виджетов (должны совпадать с реализацией WelcomeScreen)
// ---------------------------------------------------------------------------
// Тесты обнаруживают виджеты по этим ключам.
// Реализация WelcomeScreen ОБЯЗАНА использовать эти ключи.
const Key kWelcomeNameField    = Key('welcome_name_field');
const Key kWelcomeContinueBtn  = Key('welcome_continue_button');
const Key kWelcomeLoadingIndicator = Key('welcome_loading_indicator');

// ---------------------------------------------------------------------------
// Обёртка для рендеринга WelcomeScreen в тестовой среде
// ---------------------------------------------------------------------------
// Включает минимальный набор для работы AppLocalizations + Material.
Widget buildTestApp(Widget home) {
  return MaterialApp(
    // AppLocalizations.localizationsDelegates будет добавлен при реализации.
    // Пока используем минимальный набор чтобы тесты компилировались.
    locale: const Locale('en'),
    home: home,
  );
}

// ---------------------------------------------------------------------------
// Вспомогательный: инициализировать SharedPreferences с заданными значениями
// ---------------------------------------------------------------------------
Future<void> initPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
}

// ---------------------------------------------------------------------------
// Вспомогательный: сбросить UserService Supabase-мок
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

// ---------------------------------------------------------------------------
// NavigatorObserver для отслеживания навигации в тестах
// ---------------------------------------------------------------------------
class TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> replacedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replacedRoutes.add(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  bool get hasNavigatedViaReplace => replacedRoutes.isNotEmpty;

  String? get lastReplacedRouteName =>
      replacedRoutes.isNotEmpty ? replacedRoutes.last.settings.name : null;

  void reset() {
    pushedRoutes.clear();
    replacedRoutes.clear();
    poppedRoutes.clear();
  }
}
