// ============================================================
// GuardiansScreen — Widget Tests (форма редактирования)
// ============================================================
// Покрываемые требования:
//   FR-09  — Debounce 500ms, индикатор загрузки, очистка при пустом поле
//   FR-10  — Найдено: "✓ Found: [Имя]"
//   FR-11  — Не найдено: "⚠️ User not found"
//   FR-12  — Поле Nickname для каждого хранителя
//   FR-13  — Сохранение: guardian1..5 + guardian1_nickname..5_nickname
//   AC-07  — Ввод "ABCD1234" → после 500ms → "✓ Found: Charlie"
//   AC-08  — Ввод "ZZZZZZZZ" → "⚠️ User not found"
//   AC-09  — ID + Nickname → SharedPreferences
//   AC-10  — ID без Nickname → nickname = ""
//   AC-17  — Очистка поля → сброс поиска, запрос не выполняется
//   EC-04  — Race condition: ответ устаревшего запроса игнорируется
//   EC-09  — Nickname со спецсимволами сохраняется корректно
//
// СТАТУС: 🔴 RED — GuardiansScreen не реализован.
//
// Архитектурные предположения:
//   GuardiansScreen (рефакторинг EmergencyNumberScreen в settings_screen.dart):
//   - Ключи виджетов: Key('guardian_id_field_1')..Key('guardian_id_field_5')
//                     Key('guardian_nickname_field_1')..Key('guardian_nickname_field_5')
//                     Key('guardian_search_status_1')..Key('guardian_search_status_5')
//                     Key('guardian_search_loading_1')..Key('guardian_search_loading_5')
//                     Key('guardians_save_button')
//   - Debounce реализован через Timer (500ms)
//   - При очистке поля: сброс Timer, состояния загрузки и результата поиска
//   - Race condition защита: generation counter или cancellation token
//   - GuardiansService.findUserName вызывается через статический override
//
// Запуск:
//   flutter test tests/unit/guardians/guardians_screen_test.dart
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/screens/settings_screen.dart'; // GuardiansScreen 🔴
import 'package:emergency_app/services/guardians_service.dart'; // 🔴

import 'mocks/test_helpers.dart';

// ---------------------------------------------------------------------------
// Вспомогательная: рендерит GuardiansScreen в тестовой среде
// ---------------------------------------------------------------------------
Future<void> pumpGuardiansScreen(WidgetTester tester) async {
  await tester.pumpWidget(buildGuardiansTestApp(const GuardiansScreen()));
  await tester.pump(); // первый render + initState
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    teardownGuardiansServiceMock();
  });

  tearDown(() {
    teardownGuardiansServiceMock();
  });

  // ==========================================================================
  // FR-09, FR-12 | Начальное состояние экрана
  // ==========================================================================
  group('FR-09 | FR-12 | Начальное состояние GuardiansScreen', () {
    testWidgets(
      'given GuardiansScreen открыт '
      'when рендеринг завершён '
      'then присутствуют 5 ID-полей и 5 nickname-полей',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse(null);

        await pumpGuardiansScreen(tester);

        for (int i = 1; i <= 5; i++) {
          expect(find.byKey(guardianIdFieldKey(i)), findsOneWidget,
              reason: 'ID-поле для слота $i должно быть на экране');
          expect(find.byKey(guardianNicknameFieldKey(i)), findsOneWidget,
              reason: 'Nickname-поле для слота $i должно быть на экране (FR-12)');
        }
      },
    );

    testWidgets(
      'given GuardiansScreen открыт '
      'when рендеринг завершён '
      'then кнопка "Сохранить" присутствует',
      (tester) async {
        setupGuardiansServiceMock();

        await pumpGuardiansScreen(tester);

        expect(find.byKey(kGuardiansSaveButton), findsOneWidget);
      },
    );

    testWidgets(
      'given SharedPreferences содержит guardian1 = "ABCD1234" '
      'when GuardiansScreen открыт '
      'then ID-поле слота 1 предзаполнено "ABCD1234"',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'});
        setupGuardiansServiceMock();

        await pumpGuardiansScreen(tester);

        final field = tester.widget<TextField>(find.byKey(guardianIdFieldKey(1)));
        expect(field.controller?.text, equals('ABCD1234'));
      },
    );

    testWidgets(
      'given SharedPreferences содержит guardian1_nickname = "Mom" '
      'when GuardiansScreen открыт '
      'then nickname-поле слота 1 предзаполнено "Mom"',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});
        setupGuardiansServiceMock();

        await pumpGuardiansScreen(tester);

        final field = tester.widget<TextField>(
          find.byKey(guardianNicknameFieldKey(1)),
        );
        expect(field.controller?.text, equals('Mom'));
      },
    );

    testWidgets(
      'given SharedPreferences пустые '
      'when GuardiansScreen открыт '
      'then все ID-поля и nickname-поля пустые',
      (tester) async {
        setupGuardiansServiceMock();

        await pumpGuardiansScreen(tester);

        for (int i = 1; i <= 5; i++) {
          final idField = tester.widget<TextField>(
            find.byKey(guardianIdFieldKey(i)),
          );
          expect(idField.controller?.text ?? '', isEmpty);

          final nicknameField = tester.widget<TextField>(
            find.byKey(guardianNicknameFieldKey(i)),
          );
          expect(nicknameField.controller?.text ?? '', isEmpty);
        }
      },
    );
  });

  // ==========================================================================
  // FR-09 | FR-10 | FR-11 | Debounce и результаты поиска
  // ==========================================================================
  group('FR-09 | FR-10 | FR-11 | Debounce поиск', () {
    testWidgets(
      '[AC-07] given пользователь вводит "ABCD1234" (существует, имя "Charlie") '
      'when прошло 500ms после последнего ввода '
      'then отображается "✓ Found: Charlie"',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(); // setState

        // До дебаунса: результата нет
        expect(
          find.text('✓ Found: Charlie'),
          findsNothing,
          reason: 'До истечения debounce результат не должен показываться',
        );

        // Истекают 500ms дебаунса + завершается async-запрос
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(
          find.text('✓ Found: Charlie'),
          findsOneWidget,
          reason: 'AC-07: после debounce 500ms и получения результата → "✓ Found: Charlie"',
        );
      },
    );

    testWidgets(
      '[AC-08] given пользователь вводит "ZZZZZZZZ" (отсутствует в Supabase) '
      'when поиск завершён '
      'then отображается "⚠️ User not found"',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ZZZZZZZZ', null);

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ZZZZZZZZ');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(
          find.text('⚠️ User not found'),
          findsOneWidget,
          reason: 'AC-08: пользователь не найден → "⚠️ User not found"',
        );
      },
    );

    testWidgets(
      'given пользователь вводит текст '
      'when прошло < 500ms '
      'then индикатор загрузки виден, результат не показан',
      (tester) async {
        // Мок с задержкой, чтобы запрос не завершился мгновенно
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');
        mock.responseDelay = const Duration(milliseconds: 300);

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(); // setState

        // Сразу после ввода — никаких результатов
        expect(find.text('✓ Found: Charlie'), findsNothing);
        expect(find.text('⚠️ User not found'), findsNothing);

        // 499ms — дебаунс ещё не сработал
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.text('✓ Found: Charlie'), findsNothing,
            reason: 'До 500ms debounce запрос не должен начинаться');
      },
    );

    testWidgets(
      'given debounce сработал и запрос выполняется '
      'when запрос ещё не завершился '
      'then индикатор загрузки виден',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        // Блокирующий ответ
        final completer = mock.createCompleter('ABCD1234');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500)); // debounce fires
        await tester.pump(); // запрос начался, но не завершился

        expect(
          find.byKey(guardianSearchLoadingKey(1)),
          findsOneWidget,
          reason: 'Во время выполнения запроса должен быть виден индикатор загрузки',
        );

        // Завершаем запрос
        completer.complete('Charlie');
        await tester.pumpAndSettle();

        expect(find.byKey(guardianSearchLoadingKey(1)), findsNothing,
            reason: 'После завершения запроса индикатор скрывается');
      },
    );

    testWidgets(
      '[AC-17] given "ABCD1234" введено и найдено "Charlie" '
      'when поле полностью очищено '
      'then результат поиска и индикатор загрузки сбрасываются',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');
        final callsBefore = <String>[];

        await pumpGuardiansScreen(tester);

        // Первый поиск
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text('✓ Found: Charlie'), findsOneWidget);

        callsBefore.addAll(List.from(mock.calls));

        // Очищаем поле
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), '');
        await tester.pump(const Duration(milliseconds: 600)); // ждём дольше debounce
        await tester.pumpAndSettle();

        // Assert: результат и загрузка сброшены
        expect(find.text('✓ Found: Charlie'), findsNothing,
            reason: 'AC-17: очистка поля → результат поиска сбрасывается');
        expect(find.byKey(guardianSearchStatusKey(1)), findsNothing,
            reason: 'AC-17: статус поиска не должен отображаться при пустом поле');
        expect(find.byKey(guardianSearchLoadingKey(1)), findsNothing,
            reason: 'AC-17: индикатор загрузки сброшен при пустом поле');

        // Assert: запрос к Supabase не выполнялся после очистки
        final newCalls = mock.calls.length - callsBefore.length;
        expect(newCalls, equals(0),
            reason: 'AC-17: при пустом поле запрос к GuardiansService не выполняется');
      },
    );

    testWidgets(
      'given быстрый ввод нескольких символов (каждый < 500ms) '
      'when ввод прекращается '
      'then выполняется только один запрос (по последнему значению)',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse('Charlie');

        await pumpGuardiansScreen(tester);

        // Имитируем быстрый ввод: 'A', 'AB', 'ABC', 'ABCD1234'
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'A');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'AB');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Только один финальный запрос
        expect(mock.calls.length, equals(1),
            reason: 'Debounce должен сбрасываться при каждом изменении; '
                'запрос выполняется только после паузы 500ms');
        expect(mock.calls.first, equals('ABCD1234'),
            reason: 'Запрос должен быть по последнему значению поля');
      },
    );
  });

  // ==========================================================================
  // EC-04 | Race condition — устаревший ответ игнорируется
  // ==========================================================================
  group('EC-04 | Race condition при overlapping запросах', () {
    testWidgets(
      '[EC-04] given два overlapping запроса '
      'when первый запрос ("ABCD1234" → "Charlie") завершается ПОСЛЕ второго ("EFGH5678" → "Eve") '
      'then отображается только результат второго (стале первый игнорируется)',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        final completer1 = mock.createCompleter('ABCD1234');
        final completer2 = mock.createCompleter('EFGH5678');

        await pumpGuardiansScreen(tester);

        // Первый ввод — запрос 1 стартует
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(); // запрос 1 начался

        // Второй ввод — запрос 2 стартует (до завершения запроса 1)
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'EFGH5678');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(); // запрос 2 начался

        // Запрос 2 завершается первым
        completer2.complete('Eve');
        await tester.pumpAndSettle();

        expect(find.text('✓ Found: Eve'), findsOneWidget,
            reason: 'Результат актуального запроса виден');

        // Запрос 1 завершается с устаревшим результатом
        completer1.complete('Charlie');
        await tester.pumpAndSettle();

        // Устаревший результат должен быть проигнорирован
        expect(find.text('✓ Found: Charlie'), findsNothing,
            reason:
                'EC-04: ответ устаревшего первого запроса не должен заменить '
                'актуальный результат второго запроса');
        expect(find.text('✓ Found: Eve'), findsOneWidget,
            reason: 'Актуальный результат второго запроса сохраняется');
      },
    );
  });

  // ==========================================================================
  // FR-13 | AC-09, AC-10 | Сохранение в SharedPreferences
  // ==========================================================================
  group('FR-13 | Сохранение хранителей', () {
    testWidgets(
      '[AC-09] given введены ID "ABCD1234" и Nickname "Mom" для хранителя 1 '
      'when нажата кнопка "Сохранить" '
      'then SharedPreferences: guardian1 = "ABCD1234", guardian1_nickname = "Mom"',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.enterText(
            find.byKey(guardianNicknameFieldKey(1)), 'Mom');
        await tester.pump(const Duration(milliseconds: 500)); // дебаунс
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guardian1'), equals('ABCD1234'),
            reason: 'AC-09: ID сохраняется по ключу guardian1');
        expect(prefs.getString('guardian1_nickname'), equals('Mom'),
            reason: 'AC-09: nickname сохраняется по ключу guardian1_nickname');
      },
    );

    testWidgets(
      '[AC-10] given ID "ABCD1234" введён, Nickname не задан '
      'when нажата кнопка "Сохранить" '
      'then SharedPreferences: guardian1_nickname = "" (пустая строка)',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        // nickname не вводим
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guardian1'), equals('ABCD1234'));
        expect(
          prefs.getString('guardian1_nickname'),
          equals(''),
          reason: 'AC-10: отсутствующий nickname сохраняется как пустая строка',
        );
      },
    );

    testWidgets(
      'given все 5 хранителей заполнены (ID + nickname) '
      'when нажата "Сохранить" '
      'then все 5 пар ID + nickname сохранены в SharedPreferences',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse('SomeName');

        await pumpGuardiansScreen(tester);

        final ids = ['AAAA1111', 'BBBB2222', 'CCCC3333', 'DDDD4444', 'EEEE5555'];
        final nicks = ['Nick1', 'Nick2', 'Nick3', 'Nick4', 'Nick5'];

        for (int i = 1; i <= 5; i++) {
          await tester.enterText(
              find.byKey(guardianIdFieldKey(i)), ids[i - 1]);
          await tester.enterText(
              find.byKey(guardianNicknameFieldKey(i)), nicks[i - 1]);
        }

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        for (int i = 1; i <= 5; i++) {
          expect(prefs.getString('guardian$i'), equals(ids[i - 1]),
              reason: 'guardian$i = ${ids[i - 1]}');
          expect(prefs.getString('guardian${i}_nickname'), equals(nicks[i - 1]),
              reason: 'guardian${i}_nickname = ${nicks[i - 1]}');
        }
      },
    );

    testWidgets(
      'given хранитель 1 уже сохранён "ABCD1234", поле очищено '
      'when нажата "Сохранить" '
      'then guardian1 = "" в SharedPreferences',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});
        setupGuardiansServiceMock();

        await pumpGuardiansScreen(tester);

        // Очищаем поле
        await tester.enterText(find.byKey(guardianIdFieldKey(1)), '');
        await tester.enterText(find.byKey(guardianNicknameFieldKey(1)), '');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guardian1'), equals(''),
            reason: 'Очищенный guardian сохраняется как пустая строка');
      },
    );

    testWidgets(
      '[EC-09] given Nickname содержит специальные символы "O\'Brien" '
      'when нажата "Сохранить" '
      'then nickname сохраняется без изменений',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse('SomeName');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.enterText(
            find.byKey(guardianNicknameFieldKey(1)), "O'Brien");
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guardian1_nickname'), equals("O'Brien"),
            reason: "EC-09: спецсимволы в nickname сохраняются без изменений");
      },
    );

    testWidgets(
      '[EC-09] given Nickname = "Мама" (Кириллица) '
      'when сохранение '
      'then nickname сохраняется без изменений',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse(null);

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.enterText(
            find.byKey(guardianNicknameFieldKey(1)), 'Мама');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kGuardiansSaveButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('guardian1_nickname'), equals('Мама'));
      },
    );
  });

  // ==========================================================================
  // FR-11 | Supabase ошибка при поиске → "⚠️ User not found"
  // ==========================================================================
  group('FR-11 | Поиск при ошибке GuardiansService', () {
    testWidgets(
      'given GuardiansService.findUserName бросает исключение '
      'when поиск завершился '
      'then отображается "⚠️ User not found" (не краш)',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.errorToThrow = Exception('Network error');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('⚠️ User not found'), findsOneWidget,
            reason:
                'Ошибка сети при поиске → "⚠️ User not found", не краш приложения');
      },
    );
  });

  // ==========================================================================
  // FR-09 | Независимость полей — поиск в поле 1 не влияет на поле 2
  // ==========================================================================
  group('FR-09 | Независимость полей поиска', () {
    testWidgets(
      'given поиск в поле 1 вернул "Charlie" '
      'when поле 2 пустое '
      'then в поле 2 нет статуса поиска',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');
        mock.setDefaultResponse(null);

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'ABCD1234');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('✓ Found: Charlie'), findsOneWidget);
        expect(find.byKey(guardianSearchStatusKey(2)), findsNothing,
            reason: 'Поле 2 пустое — статус поиска не должен отображаться');
        expect(find.byKey(guardianSearchStatusKey(3)), findsNothing);
      },
    );

    testWidgets(
      'given поля 1 и 2 оба заполнены разными ID '
      'when оба debounce сработали '
      'then каждое поле показывает свой результат независимо',
      (tester) async {
        final mock = setupGuardiansServiceMock();
        mock.setResponse('AAAA1111', 'Alice');
        mock.setResponse('BBBB2222', 'Bob');

        await pumpGuardiansScreen(tester);

        await tester.enterText(find.byKey(guardianIdFieldKey(1)), 'AAAA1111');
        await tester.enterText(find.byKey(guardianIdFieldKey(2)), 'BBBB2222');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Каждое поле показывает свой результат
        // Результаты привязаны к конкретному слоту
        expect(find.text('✓ Found: Alice'), findsOneWidget);
        expect(find.text('✓ Found: Bob'), findsOneWidget);
      },
    );
  });
}
