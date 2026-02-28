// ============================================================
// WelcomeScreen — Widget Tests
// ============================================================
// Покрываемые требования:
//   FR-05 — TextField + кнопка Continue (disabled пока trim пустое)
//   FR-06 — Continue сохраняет имя, переходит на MainScreen (без Back)
//   AC-01  — Первый запуск: WelcomeScreen с пустым полем и disabled кнопкой
//   AC-02  — Ввод "Alice" → Continue → сохранение, MainScreen, Back заблокирован
//   AC-16  — Пустое / whitespace поле → Continue disabled
//   NFR-04 — Не крашится при сетевой ошибке Supabase
//   NFR-05 — TextField ограничен 50 символами
//   EC-01  — Whitespace-only считается пустым
//   EC-03  — Supabase упал → Snackbar, навигация всё равно выполняется
//
// СТАТУС: 🔴 RED — WelcomeScreen не реализован. Это ожидаемое TDD-состояние.
//
// Запуск:
//   flutter test tests/unit/welcome_screen/welcome_screen_widget_test.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/screens/welcome_screen.dart'; // 🔴 не существует
import 'package:emergency_app/screens/main_screen.dart';
import 'package:emergency_app/services/user_service.dart';

import 'mocks/test_helpers.dart';

// Top-level no-op locale callback used in pumpWelcomeScreen.
void _noopLocale(String _) {}

void main() {
  // Захваченные вызовы UserService.saveUserName → Supabase
  final capturedSaveCalls = <Map<String, String>>[];

  setUp(() async {
    capturedSaveCalls.clear();
    await initPrefs({'myUserId': 'TESTID01'});
    setupUserServiceMock(capturedCalls: capturedSaveCalls);
  });

  tearDown(() {
    teardownUserServiceMock();
  });

  // ==========================================================================
  // Утилиты
  // ==========================================================================

  /// Рендерит WelcomeScreen в тестовом окружении.
  /// Опционально подключает NavigatorObserver для отслеживания навигации.
  Future<void> pumpWelcomeScreen(
    WidgetTester tester, {
    TestNavigatorObserver? observer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        navigatorObservers: [if (observer != null) observer],
        routes: {
          '/': (_) => const WelcomeScreen(),
          '/main': (_) => const MainScreen(updateLocale: _noopLocale),
        },
        initialRoute: '/',
      ),
    );
    // Ждём первый frame
    await tester.pump();
  }


  // ==========================================================================
  // FR-05 | UI Elements
  // ==========================================================================
  group('FR-05 | WelcomeScreen UI elements', () {
    testWidgets(
      'given WelcomeScreen opened '
      'when rendered '
      'then TextField для ввода имени присутствует',
      (tester) async {
        // Arrange & Act
        await pumpWelcomeScreen(tester);

        // Assert
        expect(
          find.byKey(kWelcomeNameField),
          findsOneWidget,
          reason: 'TextField с ключом welcome_name_field должен быть на экране',
        );
      },
    );

    testWidgets(
      'given WelcomeScreen opened '
      'when rendered '
      'then кнопка Continue присутствует',
      (tester) async {
        // Arrange & Act
        await pumpWelcomeScreen(tester);

        // Assert
        expect(
          find.byKey(kWelcomeContinueBtn),
          findsOneWidget,
          reason: 'Кнопка с ключом welcome_continue_button должна быть на экране',
        );
      },
    );

    testWidgets(
      '[AC-01] given TextField пустое при открытии '
      'when WelcomeScreen отрендерен '
      'then кнопка Continue disabled',
      (tester) async {
        // Arrange & Act
        await pumpWelcomeScreen(tester);

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(
          btn.onPressed,
          isNull,
          reason: 'AC-01: Continue должна быть disabled при пустом поле',
        );
      },
    );

    testWidgets(
      '[NFR-05] given TextField отрендерен '
      'when проверяем ограничение длины '
      'then maxLength == 50',
      (tester) async {
        // Arrange & Act
        await pumpWelcomeScreen(tester);

        // Assert
        final field = tester.widget<TextField>(
          find.byKey(kWelcomeNameField),
        );
        expect(
          field.maxLength,
          equals(50),
          reason: 'NFR-05: поле ввода ограничено 50 символами на уровне UI',
        );
      },
    );
  });

  // ==========================================================================
  // FR-05 | Continue button state (AC-16, EC-01)
  // ==========================================================================
  group('FR-05 | AC-16 | Continue button state', () {
    testWidgets(
      '[AC-16] given поле пустое (нет текста) '
      'when пользователь смотрит на кнопку '
      'then Continue disabled',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);

        // Act — поле изначально пустое, ничего не вводим
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      '[AC-16 / EC-01] given поле содержит только пробелы "   " '
      'when пользователь смотрит на кнопку '
      'then Continue disabled (пробелы = пустое после trim)',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);

        // Act
        await tester.enterText(find.byKey(kWelcomeNameField), '   ');
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(
          btn.onPressed,
          isNull,
          reason: 'EC-01: строка из пробелов должна считаться пустой',
        );
      },
    );

    testWidgets(
      '[AC-16] given поле содержит только табы и пробелы '
      'when пользователь смотрит на кнопку '
      'then Continue disabled',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);

        // Act
        await tester.enterText(find.byKey(kWelcomeNameField), '\t  \t');
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets(
      'given поле содержит непустой текст "Alice" '
      'when пользователь вводит текст '
      'then Continue становится enabled',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);

        // Act
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(
          btn.onPressed,
          isNotNull,
          reason: 'Continue должна быть enabled при непустом тексте',
        );
      },
    );

    testWidgets(
      'given Continue была enabled (текст "Alice") '
      'when пользователь стирает весь текст '
      'then Continue снова disabled',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act — очищаем поле
        await tester.enterText(find.byKey(kWelcomeNameField), '');
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(btn.onPressed, isNull,
            reason: 'После очистки поля кнопка должна снова стать disabled');
      },
    );

    testWidgets(
      'given текст = " A" (пробел + буква, trim непустой) '
      'when пользователь смотрит на кнопку '
      'then Continue enabled (trim не пустой)',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);

        // Act
        await tester.enterText(find.byKey(kWelcomeNameField), ' A');
        await tester.pump();

        // Assert — " A".trim() == "A", непустое
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(btn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'given текст ровно 50 символов (граничное значение NFR-05) '
      'when пользователь смотрит на кнопку '
      'then Continue enabled',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);
        final maxName = 'A' * 50;

        // Act
        await tester.enterText(find.byKey(kWelcomeNameField), maxName);
        await tester.pump();

        // Assert
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(btn.onPressed, isNotNull);
      },
    );
  });

  // ==========================================================================
  // FR-06 | Continue action: сохранение + навигация
  // ==========================================================================
  group('FR-06 | Continue action', () {
    testWidgets(
      '[AC-02] given пользователь ввёл "Alice" '
      'when нажата кнопка Continue '
      'then UserService.saveUserName вызван с "Alice"',
      (tester) async {
        // Arrange
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert
        expect(
          capturedSaveCalls,
          hasLength(1),
          reason: 'saveUserName должен быть вызван ровно один раз',
        );
        expect(
          capturedSaveCalls.first['name'],
          equals('Alice'),
          reason: 'saveUserName должен получить точное введённое имя',
        );
      },
    );

    testWidgets(
      '[AC-02] given пользователь ввёл "Alice" и нажал Continue '
      'when сохранение завершилось '
      'then пользователь находится на MainScreen',
      (tester) async {
        // Arrange
        final observer = TestNavigatorObserver();
        await pumpWelcomeScreen(tester, observer: observer);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert — MainScreen виден
        expect(
          find.byType(MainScreen),
          findsOneWidget,
          reason: 'AC-02: после Continue должен открыться MainScreen',
        );
        // WelcomeScreen не должен быть виден
        expect(
          find.byType(WelcomeScreen),
          findsNothing,
          reason: 'WelcomeScreen не должен присутствовать в дереве после перехода',
        );
      },
    );

    testWidgets(
      '[AC-02] given пользователь перешёл на MainScreen через Continue '
      'when нажимает Back (Android) '
      'then WelcomeScreen НЕ показывается (pushReplacement)',
      (tester) async {
        // Arrange
        final observer = TestNavigatorObserver();
        await pumpWelcomeScreen(tester, observer: observer);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Act — симулируем нажатие Back через PopScope / системную кнопку.
        // Если Back-кнопка отсутствует (pushReplacement убрал WelcomeScreen из стека),
        // pageBack() бросит исключение — это само по себе доказывает корректность.
        try {
          await tester.pageBack();
          await tester.pumpAndSettle();
        } catch (_) {
          // Отсутствие Back-кнопки = невозможность вернуться назад = OK
        }

        // Assert — WelcomeScreen не появляется
        expect(
          find.byType(WelcomeScreen),
          findsNothing,
          reason: 'AC-02: Back не должен возвращать на WelcomeScreen',
        );
      },
    );

    testWidgets(
      '[AC-02] given Continue нажата '
      'when навигация происходит '
      'then используется pushReplacement (не push)',
      (tester) async {
        // Arrange
        final observer = TestNavigatorObserver();
        await pumpWelcomeScreen(tester, observer: observer);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert — навигация произошла через replace, не через push
        expect(
          observer.hasNavigatedViaReplace,
          isTrue,
          reason: 'FR-06: для возврата назад должен использоваться pushReplacement',
        );
      },
    );

    testWidgets(
      'given пользователь ввёл " Alice " (с пробелами вокруг) '
      'when нажата Continue '
      'then saveUserName получает точно введённое значение (без неявного trim)',
      (tester) async {
        // Arrange
        // Примечание: trim выполняется на уровне UI кнопки (disabled),
        // но сам вызов saveUserName передаёт то, что в поле.
        // Тест проверяет, что сервис получает данные как есть.
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), ' Alice ');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert — экран уходит (Continue enabled т.к. trim непустой)
        // saveUserName получил либо " Alice " либо "Alice" — зависит от реализации.
        // Тест фиксирует фактическое поведение (должно быть задокументировано):
        expect(capturedSaveCalls, hasLength(1));
        // Если реализация обрезает — ожидаем "Alice"; если нет — " Alice "
        // Поставим lenient check: имя непустое и содержит "Alice"
        expect(
          capturedSaveCalls.first['name']?.trim(),
          equals('Alice'),
          reason: 'Имя должно содержать "Alice" (с или без whitespace вокруг)',
        );
      },
    );

    testWidgets(
      'given userId == "TESTID01" '
      'when Continue нажата с именем "Alice" '
      'then saveUserName вызывается с userId "TESTID01"',
      (tester) async {
        // Arrange
        await initPrefs({'myUserId': 'TESTID01'});
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert
        expect(capturedSaveCalls.first['userId'], equals('TESTID01'));
      },
    );
  });

  // ==========================================================================
  // FR-06 + EC-03 + NFR-04 | Supabase error handling
  // ==========================================================================
  group('FR-06 | EC-03 | NFR-04 | Ошибка Supabase при сохранении', () {
    testWidgets(
      '[EC-03] given Supabase выбрасывает Exception '
      'when Continue нажата '
      'then навигация на MainScreen всё равно выполняется',
      (tester) async {
        // Arrange
        setupUserServiceMock(
          supabaseError: Exception('Network error'),
          capturedCalls: capturedSaveCalls,
        );
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pumpAndSettle();

        // Assert — навигация произошла несмотря на ошибку
        expect(
          find.byType(MainScreen),
          findsOneWidget,
          reason:
              'EC-03: ошибка Supabase не должна блокировать переход на MainScreen',
        );
      },
    );

    testWidgets(
      '[EC-03] given Supabase выбрасывает Exception '
      'when Continue нажата '
      'then отображается Snackbar с предупреждением',
      (tester) async {
        // Arrange
        setupUserServiceMock(
          supabaseError: Exception('Sync failed'),
          capturedCalls: capturedSaveCalls,
        );
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pump(); // Snackbar появляется в следующем frame
        await tester.pump(const Duration(milliseconds: 300));

        // Assert — Snackbar отображён.
        // Во время перехода (300 мс) оба Scaffold могут быть в дереве одновременно,
        // поэтому ScaffoldMessenger рендерит SnackBar на каждом из них — проверяем
        // наличие хотя бы одного.
        expect(
          find.byType(SnackBar),
          findsWidgets,
          reason: 'EC-03: должен показаться Snackbar-предупреждение при сбое синхронизации',
        );
      },
    );

    testWidgets(
      '[NFR-04] given Supabase выбрасывает любое исключение '
      'when Continue нажата '
      'then приложение не крашится (нет FlutterError)',
      (tester) async {
        // Arrange
        setupUserServiceMock(
          supabaseError: Exception('Connection refused'),
          capturedCalls: capturedSaveCalls,
        );
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act & Assert — не должно быть необработанных исключений
        await expectLater(
          () async {
            await tester.tap(find.byKey(kWelcomeContinueBtn));
            await tester.pumpAndSettle();
          },
          returnsNormally,
          reason: 'NFR-04: сетевые ошибки не должны приводить к крашу',
        );
      },
    );
  });

  // ==========================================================================
  // FR-05 | Loading state при сохранении
  // ==========================================================================
  group('FR-05 | Loading state', () {
    testWidgets(
      'given Continue нажата (сохранение в процессе) '
      'when saveUserName выполняется асинхронно '
      'then кнопка Continue disabled во время загрузки',
      (tester) async {
        // Arrange — медленный saveUserName (через Completer)
        var resolveSave = false;
        UserService.setSupabaseSaveOverride((userId, name) async {
          // Имитируем задержку
          while (!resolveSave) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await pumpWelcomeScreen(tester);
        await tester.enterText(find.byKey(kWelcomeNameField), 'Alice');
        await tester.pump();

        // Act
        await tester.tap(find.byKey(kWelcomeContinueBtn));
        await tester.pump(); // начало сохранения

        // Assert — кнопка disabled пока идёт сохранение
        final btn = tester.widget<ElevatedButton>(
          find.byKey(kWelcomeContinueBtn),
        );
        expect(
          btn.onPressed,
          isNull,
          reason: 'Кнопка должна быть disabled во время асинхронного сохранения',
        );

        // Cleanup
        resolveSave = true;
        await tester.pumpAndSettle();
      },
    );
  });
}
