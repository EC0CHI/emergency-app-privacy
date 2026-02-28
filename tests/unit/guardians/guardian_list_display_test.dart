// ============================================================
// Guardian List Display — Widget Tests
// ============================================================
// Покрываемые требования:
//   FR-14  — Параллельная загрузка имён хранителей (Future.wait)
//   FR-15  — Отображение при наличии сети (4 варианта)
//   FR-16  — Отображение при ошибке Supabase (только User ID)
//   AC-11  — имя + nickname → "Charlie (Mom)" + ID ниже
//   AC-12  — имя, нет nickname → "Charlie" + ID ниже
//   AC-13  — ошибка Supabase + nickname "Mom" → только "ABCD1234"
//   EC-07  — Порядок отображения = порядок guardian1..5 (не порядок ответов)
//   NFR-07 — Запросы параллельны (не последовательны)
//
// СТАТУС: 🔴 RED — GuardianListWidget не реализован.
//
// Архитектурный контракт (GuardianListWidget):
//   - Читает guardian1..5 из SharedPreferences
//   - Для каждого непустого ID вызывает GuardiansService.findUserName()
//   - Все вызовы выполняются через Future.wait (параллельно)
//   - Отображает элементы в порядке guardian1..5 (не порядке завершения Future)
//   - Ключи виджетов:
//       Key('guardian_list_item_1')..Key('guardian_list_item_5')
//       Key('guardian_list_primary_1')..Key('guardian_list_primary_5')
//       Key('guardian_list_secondary_1')..Key('guardian_list_secondary_5')
//       Key('guardian_list_loading_1')..Key('guardian_list_loading_5')
//   - При ошибке GuardiansService.findUserName → FR-16: только User ID
//   - Пустые слоты (guardian = '') не отображаются
//
//   Импорт:
//     import 'package:emergency_app/widgets/guardian_list_widget.dart';
//     // GuardianListWidget — новый виджет (🔴 не существует)
//
// Запуск:
//   flutter test tests/unit/guardians/guardian_list_display_test.dart
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/widgets/guardian_list_widget.dart'; // 🔴 не существует
import 'package:emergency_app/services/guardians_service.dart'; // 🔴 не существует

import 'mocks/test_helpers.dart';

// ---------------------------------------------------------------------------
// Вспомогательная: рендерит GuardianListWidget в тестовой среде
// ---------------------------------------------------------------------------
Future<void> pumpGuardianList(WidgetTester tester) async {
  await tester.pumpWidget(buildGuardiansTestApp(const GuardianListWidget()));
  await tester.pump(); // initState запускает загрузку
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
  // FR-14 | NFR-07 | Параллельная загрузка имён
  // ==========================================================================
  group('FR-14 | NFR-07 | Параллельная загрузка', () {
    testWidgets(
      'given 3 хранителя сохранены '
      'when список загружается '
      'then для каждого вызывается findUserName — все три вызова',
      (tester) async {
        await setGuardianPrefs(ids: {
          1: 'AAAA1111',
          2: 'BBBB2222',
          3: 'CCCC3333',
        });

        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse(null);

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        expect(mock.calls.length, equals(3),
            reason: 'FR-14: для каждого сохранённого guardian вызывается findUserName');
        expect(mock.calls, containsAll(['AAAA1111', 'BBBB2222', 'CCCC3333']));
      },
    );

    testWidgets(
      '[NFR-07] given 3 хранителя '
      'when список загружается '
      'then все запросы стартуют до завершения первого (параллельно)',
      (tester) async {
        await setGuardianPrefs(ids: {
          1: 'AAAA1111',
          2: 'BBBB2222',
          3: 'CCCC3333',
        });

        final mock = setupGuardiansServiceMock();
        final completer1 = mock.createCompleter('AAAA1111'); // блокирует
        final completer2 = mock.createCompleter('BBBB2222');
        final completer3 = mock.createCompleter('CCCC3333');

        await pumpGuardianList(tester);
        await tester.pump(); // initState + начало загрузки

        // Все три запроса должны были стартовать ДО завершения любого из них
        // (потому что они идут через Future.wait, а не await-последовательно)
        expect(mock.calls.length, equals(3),
            reason:
                'NFR-07: все 3 запроса стартовали параллельно до завершения '
                'первого (Future.wait, не sequential await)');

        // Завершаем все
        completer1.complete('Alice');
        completer2.complete('Bob');
        completer3.complete('Charlie');
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'given пустые слоты (guardian3..5 = "") '
      'when список загружается '
      'then findUserName вызывается только для непустых ID',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'AAAA1111', 2: 'BBBB2222'});

        final mock = setupGuardiansServiceMock();
        mock.setDefaultResponse(null);

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        expect(mock.calls.length, equals(2),
            reason: 'Пустые слоты не вызывают запросы к Supabase');
        expect(mock.calls, isNot(contains('')));
      },
    );

    testWidgets(
      'given нет сохранённых хранителей '
      'when список открывается '
      'then findUserName не вызывается, список пуст',
      (tester) async {
        final mock = setupGuardiansServiceMock();

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        expect(mock.calls, isEmpty,
            reason: 'Без хранителей запросов к GuardiansService быть не должно');
      },
    );
  });

  // ==========================================================================
  // FR-15 | Варианты отображения при наличии сети (4 случая)
  // ==========================================================================
  group('FR-15 | Отображение при наличии сети', () {
    testWidgets(
      '[AC-11] given guardian "ABCD1234", Supabase имя "Charlie", Nickname "Mom" '
      'when список загружен (сеть есть) '
      'then основная строка = "Charlie (Mom)", вторая строка = "ABCD1234"',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});

        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        // Основная строка
        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('Charlie (Mom)'),
            reason: 'AC-11: Supabase имя + Nickname → "Имя (Nickname)"');

        // Вторичная строка (User ID мелким шрифтом)
        final secondaryWidget = tester.widget<Text>(
          find.byKey(guardianListSecondaryTextKey(1)),
        );
        expect(secondaryWidget.data, equals('ABCD1234'),
            reason: 'AC-11: User ID отображается под именем мелким шрифтом');
      },
    );

    testWidgets(
      '[AC-12] given guardian "ABCD1234", Supabase имя "Charlie", Nickname не задан '
      'when список загружен '
      'then основная строка = "Charlie", вторая строка = "ABCD1234"',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'});
        // nickname не задан → SharedPreferences не содержит guardian1_nickname
        // или guardian1_nickname = ''

        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Charlie');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('Charlie'),
            reason: 'AC-12: Supabase имя без Nickname → просто "Имя"');

        final secondaryWidget = tester.widget<Text>(
          find.byKey(guardianListSecondaryTextKey(1)),
        );
        expect(secondaryWidget.data, equals('ABCD1234'));
      },
    );

    testWidgets(
      'given guardian "ABCD1234", Supabase вернул null (нет имени), Nickname "Mom" '
      'when список загружен '
      'then основная строка = "Mom", вторая строка = "ABCD1234"',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});

        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', null); // Supabase не вернул имя

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('Mom'),
            reason:
                'FR-15: Supabase вернул null + Nickname задан → основная строка = Nickname');

        final secondaryWidget = tester.widget<Text>(
          find.byKey(guardianListSecondaryTextKey(1)),
        );
        expect(secondaryWidget.data, equals('ABCD1234'));
      },
    );

    testWidgets(
      'given guardian "ABCD1234", Supabase вернул null, Nickname не задан '
      'when список загружен '
      'then основная строка = "ABCD1234" (только User ID)',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'});

        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', null);

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('ABCD1234'),
            reason:
                'FR-15: Supabase null + нет Nickname → основная строка = User ID');

        // Вторичная строка может отсутствовать или дублировать ID
        // (реализация выбирает сама)
      },
    );
  });

  // ==========================================================================
  // FR-16 | AC-13 | Ошибка Supabase — только User ID
  // ==========================================================================
  group('FR-16 | Ошибка Supabase при загрузке списка', () {
    testWidgets(
      '[AC-13] given Supabase бросает исключение, Nickname "Mom" сохранён '
      'when список хранителей загружается '
      'then отображается только "ABCD1234" (Nickname "Mom" НЕ показывается)',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});

        final mock = setupGuardiansServiceMock();
        mock.errorToThrow = Exception('No internet connection');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('ABCD1234'),
            reason:
                'AC-13: FR-16: при ошибке Supabase — только User ID, '
                'Nickname не отображается даже если есть локально');
        expect(find.text('Mom'), findsNothing,
            reason:
                'AC-13: C-04: кэширование имён не реализовано — '
                'при ошибке сети Nickname не компенсирует отсутствие Supabase имени');
      },
    );

    testWidgets(
      '[AC-13] given Supabase ошибка, Nickname не задан '
      'when список загружается '
      'then отображается только User ID, приложение не падает',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'});

        final mock = setupGuardiansServiceMock();
        mock.errorToThrow = Exception('Timeout');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        final primaryWidget = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        expect(primaryWidget.data, equals('ABCD1234'),
            reason: 'FR-16: ошибка Supabase без Nickname → User ID');
      },
    );

    testWidgets(
      'given Supabase ошибка для ВСЕХ хранителей '
      'when список загружается '
      'then все хранители показаны как User ID, приложение не падает (NFR-04)',
      (tester) async {
        await setGuardianPrefs(
          ids: {1: 'AAAA1111', 2: 'BBBB2222', 3: 'CCCC3333'},
          nicknames: {1: 'Nick1', 2: 'Nick2', 3: 'Nick3'},
        );

        final mock = setupGuardiansServiceMock();
        mock.errorToThrow = Exception('Network unavailable');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        // Каждый хранитель показан как User ID
        expect(
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(1))).data,
          equals('AAAA1111'),
        );
        expect(
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(2))).data,
          equals('BBBB2222'),
        );
        expect(
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(3))).data,
          equals('CCCC3333'),
        );

        // Nickname'ы не показываются
        expect(find.text('Nick1'), findsNothing);
        expect(find.text('Nick2'), findsNothing);
        expect(find.text('Nick3'), findsNothing);
      },
    );

    testWidgets(
      'given Supabase ошибка '
      'when список загружается '
      'then приложение не падает (NFR-04)',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'}, nicknames: {1: 'Mom'});

        final mock = setupGuardiansServiceMock();
        mock.errorToThrow = Exception('Critical failure');

        // Должен рендериться без exception
        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        // Виджет всё ещё видим
        expect(find.byType(GuardianListWidget), findsOneWidget,
            reason: 'NFR-04: ошибка Supabase не должна крашить приложение');
      },
    );
  });

  // ==========================================================================
  // EC-07 | Порядок отображения = guardian1..5 (не порядок ответов)
  // ==========================================================================
  group('EC-07 | Порядок хранителей независим от порядка Future', () {
    testWidgets(
      '[EC-07] given guardian1 = "AAAA1111" и guardian2 = "BBBB2222" '
      'when guardian2 (Future) завершается РАНЬШЕ guardian1 '
      'then в списке guardian1 всё равно первый',
      (tester) async {
        await setGuardianPrefs(ids: {
          1: 'AAAA1111', // Alice
          2: 'BBBB2222', // Bob
        });

        final mock = setupGuardiansServiceMock();
        final completer1 = mock.createCompleter('AAAA1111'); // guardian1 — медленный
        final completer2 = mock.createCompleter('BBBB2222'); // guardian2 — быстрый

        await pumpGuardianList(tester);
        await tester.pump(); // запросы начались

        // guardian2 завершается первым
        completer2.complete('Bob');
        await tester.pump();

        // guardian1 завершается вторым
        completer1.complete('Alice');
        await tester.pumpAndSettle();

        // Элемент 1 должен быть Alice (guardian1), элемент 2 — Bob (guardian2)
        final primary1 = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(1)),
        );
        final primary2 = tester.widget<Text>(
          find.byKey(guardianListPrimaryTextKey(2)),
        );

        expect(primary1.data, equals('Alice'),
            reason: 'EC-07: guardian1 = AAAA1111 → Alice; порядок по слоту, не по скорости ответа');
        expect(primary2.data, equals('Bob'),
            reason: 'EC-07: guardian2 = BBBB2222 → Bob');
      },
    );

    testWidgets(
      '[EC-07] given 5 хранителей с именами '
      'when ответы приходят в обратном порядке (5→1) '
      'then список отображает в порядке 1..5',
      (tester) async {
        await setGuardianPrefs(ids: {
          1: 'ID000001',
          2: 'ID000002',
          3: 'ID000003',
          4: 'ID000004',
          5: 'ID000005',
        });

        final mock = setupGuardiansServiceMock();
        final completers = {
          'ID000001': mock.createCompleter('ID000001'),
          'ID000002': mock.createCompleter('ID000002'),
          'ID000003': mock.createCompleter('ID000003'),
          'ID000004': mock.createCompleter('ID000004'),
          'ID000005': mock.createCompleter('ID000005'),
        };

        await pumpGuardianList(tester);
        await tester.pump();

        // Завершаем в обратном порядке: 5, 4, 3, 2, 1
        completers['ID000005']!.complete('Eve5');
        completers['ID000004']!.complete('Dan4');
        completers['ID000003']!.complete('Charlie3');
        completers['ID000002']!.complete('Bob2');
        completers['ID000001']!.complete('Alice1');
        await tester.pumpAndSettle();

        // Порядок отображения должен быть 1..5
        final names = [
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(1))).data,
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(2))).data,
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(3))).data,
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(4))).data,
          tester.widget<Text>(find.byKey(guardianListPrimaryTextKey(5))).data,
        ];

        expect(names, equals(['Alice1', 'Bob2', 'Charlie3', 'Dan4', 'Eve5']),
            reason:
                'EC-07: порядок в списке = порядок guardian1..5, '
                'независимо от очерёдности завершения Future.wait');
      },
    );
  });

  // ==========================================================================
  // Состояние загрузки
  // ==========================================================================
  group('Loading state при загрузке списка', () {
    testWidgets(
      'given список открывается '
      'when запросы ещё не завершились '
      'then элементы показывают индикатор загрузки',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234'});

        final mock = setupGuardiansServiceMock();
        final completer = mock.createCompleter('ABCD1234'); // блокируем ответ

        await pumpGuardianList(tester);
        await tester.pump(); // запрос начался, не завершился

        expect(find.byKey(guardianListLoadingKey(1)), findsOneWidget,
            reason: 'Пока имя загружается — должен быть виден индикатор загрузки');

        // Завершаем
        completer.complete('Alice');
        await tester.pumpAndSettle();

        expect(find.byKey(guardianListLoadingKey(1)), findsNothing,
            reason: 'После загрузки имени индикатор скрывается');
      },
    );

    testWidgets(
      'given список загружен успешно '
      'when имена получены '
      'then индикаторы загрузки не видны',
      (tester) async {
        await setGuardianPrefs(ids: {1: 'ABCD1234', 2: 'EFGH5678'});

        final mock = setupGuardiansServiceMock();
        mock.setResponse('ABCD1234', 'Alice');
        mock.setResponse('EFGH5678', 'Bob');

        await pumpGuardianList(tester);
        await tester.pumpAndSettle();

        expect(find.byKey(guardianListLoadingKey(1)), findsNothing);
        expect(find.byKey(guardianListLoadingKey(2)), findsNothing);
      },
    );
  });
}
