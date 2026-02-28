// ============================================================
// App Routing — Widget Tests
// ============================================================
// Покрываемые требования:
//   FR-04 — WelcomeScreen показывается при отсутствии имени
//   FR-07 — Роутинг: hasUserName() → WelcomeScreen или MainScreen
//   AC-01  — Первый запуск: нет user_name → WelcomeScreen
//   AC-03  — user_name = "Alice" в prefs → MainScreen (без WelcomeScreen)
//   EC-11  — Legacy-пользователь (userId есть, user_name нет) → WelcomeScreen
//   EC-10  — Смена языка не влияет на отображение имени / роутинг
//
// СТАТУС: 🔴 RED — Роутинг в MyApp не реализован. Ожидаемое TDD-состояние.
//
// Архитектурное предположение:
//   MyApp._MyAppState.initState() вызывает UserService.hasUserName() и
//   устанавливает начальный экран: WelcomeScreen или MainScreen.
//   Для этого MyApp принимает параметр initialScreen или использует FutureBuilder.
//
// Запуск:
//   flutter test tests/unit/welcome_screen/app_routing_test.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/main.dart';               // MyApp
import 'package:emergency_app/screens/welcome_screen.dart'; // 🔴 не существует
import 'package:emergency_app/screens/main_screen.dart';

import 'mocks/test_helpers.dart';

// ---------------------------------------------------------------------------
// Вспомогательная: рендерит MyApp в тестовой среде.
//
// В реальном приложении MyApp инициализирует Supabase/OneSignal в main().
// В тестах мы рендерим только MyApp widget (без вызовов main()),
// поэтому тяжёлые сервисы не инициализируются.
//
// MyApp должен быть написан так, чтобы работать без явного вызова main():
//   - не вызывать Supabase.instance / OneSignal в build/initState
//   - зависеть только от SharedPreferences для роутинга
// ---------------------------------------------------------------------------
Future<void> pumpMyApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  // Даём initState завершить async-проверку hasUserName()
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    teardownUserServiceMock();
  });

  tearDown(() {
    teardownUserServiceMock();
  });

  // ==========================================================================
  // FR-04 / FR-07 | Роутинг: нет имени → WelcomeScreen
  // ==========================================================================
  group('FR-04 | FR-07 | Роутинг при отсутствии имени', () {
    testWidgets(
      '[AC-01] given SharedPreferences полностью пустые (первый запуск) '
      'when MyApp запускается '
      'then отображается WelcomeScreen',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(
          find.byType(WelcomeScreen),
          findsOneWidget,
          reason: 'AC-01: при первом запуске (нет user_name) должен показаться WelcomeScreen',
        );
        expect(
          find.byType(MainScreen),
          findsNothing,
          reason: 'MainScreen не должен отображаться при отсутствии имени',
        );
      },
    );

    testWidgets(
      '[AC-01] given user_name отсутствует, но myUserId существует '
      'when MyApp запускается '
      'then отображается WelcomeScreen (не MainScreen)',
      (tester) async {
        // Arrange — userId есть (OneSignal инициализирован), имени нет
        SharedPreferences.setMockInitialValues({'myUserId': 'ABCD1234'});

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(WelcomeScreen), findsOneWidget);
        expect(find.byType(MainScreen), findsNothing);
      },
    );

    testWidgets(
      'given user_name = "" (пустая строка) '
      'when MyApp запускается '
      'then отображается WelcomeScreen (пустая строка = имя не установлено)',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': '',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(WelcomeScreen), findsOneWidget,
            reason: 'Пустая строка в prefs = имя не установлено → WelcomeScreen');
        expect(find.byType(MainScreen), findsNothing);
      },
    );

    testWidgets(
      '[AC-01] given WelcomeScreen показан '
      'when рендеринг завершён '
      'then поле ввода пустое и кнопка Continue disabled',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({});

        // Act
        await pumpMyApp(tester);

        // Assert — поле пустое
        final field = tester.widget<TextField>(find.byKey(kWelcomeNameField));
        expect(field.controller?.text ?? '', isEmpty,
            reason: 'AC-01: TextField должен быть пустым при первом запуске');

        // Assert — кнопка disabled
        final btn = tester.widget<ElevatedButton>(find.byKey(kWelcomeContinueBtn));
        expect(btn.onPressed, isNull,
            reason: 'AC-01: Continue должна быть disabled при пустом поле');
      },
    );
  });

  // ==========================================================================
  // FR-07 | Роутинг: имя есть → MainScreen
  // ==========================================================================
  group('FR-07 | Роутинг при наличии имени', () {
    testWidgets(
      '[AC-03] given user_name = "Alice" в SharedPreferences '
      'when MyApp запускается '
      'then отображается MainScreen',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': 'Alice',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(
          find.byType(MainScreen),
          findsOneWidget,
          reason: 'AC-03: при наличии user_name должен открыться MainScreen',
        );
        expect(
          find.byType(WelcomeScreen),
          findsNothing,
          reason: 'AC-03: WelcomeScreen не должен показываться если имя есть',
        );
      },
    );

    testWidgets(
      'given user_name = "Алиса" (Unicode) '
      'when MyApp запускается '
      'then отображается MainScreen',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': 'Алиса',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
    );

    testWidgets(
      'given user_name = "A" (минимальное валидное имя — 1 символ) '
      'when MyApp запускается '
      'then отображается MainScreen',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': 'A',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
      },
    );

    testWidgets(
      'given user_name = 50 символов (максимальное имя) '
      'when MyApp запускается '
      'then отображается MainScreen',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': 'B' * 50,
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
      },
    );
  });

  // ==========================================================================
  // EC-11 | Legacy-пользователи (до добавления username-системы)
  // ==========================================================================
  group('EC-11 | Legacy-пользователи после обновления', () {
    testWidgets(
      '[EC-11] given существующий пользователь: userId есть, user_name отсутствует '
      'when приложение обновлено и запускается '
      'then показывается WelcomeScreen (принудительный ввод имени)',
      (tester) async {
        // Arrange — симулируем состояние после обновления приложения:
        // userId и onesignal-данные есть, user_name нет
        SharedPreferences.setMockInitialValues({
          'myUserId': 'LEGACY01',
          // user_name намеренно отсутствует
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(
          find.byType(WelcomeScreen),
          findsOneWidget,
          reason:
              'EC-11: legacy-пользователь без user_name должен увидеть WelcomeScreen '
              'и ввести имя как при первом запуске',
        );
      },
    );

    testWidgets(
      '[EC-11] given legacy-пользователь прошёл WelcomeScreen и ввёл имя '
      'when приложение перезапускается '
      'then показывается MainScreen (без повторного WelcomeScreen)',
      (tester) async {
        // Arrange — после прохождения WelcomeScreen имя сохранено
        SharedPreferences.setMockInitialValues({
          'myUserId': 'LEGACY01',
          'user_name': 'Bob',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
    );
  });

  // ==========================================================================
  // FR-07 | Роутинг: состояние загрузки (пока hasUserName() выполняется)
  // ==========================================================================
  group('FR-07 | Loading state при запуске', () {
    testWidgets(
      'given MyApp запущен '
      'when hasUserName() ещё не завершился (async) '
      'then отображается индикатор загрузки (не WelcomeScreen и не MainScreen)',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({'myUserId': 'ABCD1234'});

        // Act — пампим только первый frame (до завершения async)
        await tester.pumpWidget(const MyApp());
        await tester.pump(); // первый render, initState начался но не завершился

        // Assert — ни WelcomeScreen, ни MainScreen ещё не должны быть отрендерены
        // (или показывается экран загрузки)
        // WelcomeScreen и MainScreen не видны пока routing не завершился
        final hasWelcome = find.byType(WelcomeScreen).evaluate().isNotEmpty;
        final hasMain = find.byType(MainScreen).evaluate().isNotEmpty;

        // Либо виден loading indicator, либо не виден ни один из целевых экранов
        if (hasWelcome || hasMain) {
          // Если один из них уже виден — роутинг синхронный (тоже допустимо)
          // Тест пропускается как N/A
          return;
        }

        // Иначе — должен быть loading indicator
        expect(
          find.byKey(kWelcomeLoadingIndicator).evaluate().isNotEmpty ||
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
          isTrue,
          reason: 'Во время async-определения роутинга должен показываться loading state',
        );
      },
    );
  });

  // ==========================================================================
  // EC-10 | Смена языка не влияет на роутинг
  // ==========================================================================
  group('EC-10 | Смена языка не влияет на роутинг', () {
    testWidgets(
      'given user_name = "Alice", язык = "zh" '
      'when MyApp запускается '
      'then всё равно показывается MainScreen (не WelcomeScreen)',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': 'Alice',
          'language': 'zh', // китайский язык
        });

        // Act
        await pumpMyApp(tester);

        // Assert — смена языка не ломает роутинг
        expect(find.byType(MainScreen), findsOneWidget);
        expect(find.byType(WelcomeScreen), findsNothing);
      },
    );

    testWidgets(
      'given нет user_name, язык = "en" '
      'when MyApp запускается '
      'then показывается WelcomeScreen независимо от языка',
      (tester) async {
        // Arrange
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'language': 'en',
        });

        // Act
        await pumpMyApp(tester);

        // Assert
        expect(find.byType(WelcomeScreen), findsOneWidget);
      },
    );
  });
}
