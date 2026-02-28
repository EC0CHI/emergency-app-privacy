// ============================================================
// MainScreen — Widget Tests
// ============================================================
// Покрываемые требования:
//   FR-17  — Отображение имени пользователя над ID в карточке "My ID"
//   FR-18  — Кнопка "Edit Name" в карточке "My ID"
//   FR-19  — Диалог "Edit Name": предзаполнение, валидация, сохранение, отмена
//   AC-04  — MainScreen с именем: имя над ID + кнопка "Edit Name"
//   AC-05  — Диалог предзаполнен текущим именем
//   AC-06  — Подтверждение: карточка обновляется, SharedPreferences/Supabase обновлены
//   AC-18  — Пустое поле в диалоге: кнопка подтверждения disabled
//
// ⚠️  ЗАМЕЧАНИЕ ПО НУМЕРАЦИИ:
//   Пользователь указал FR-21 — FR-24, которых нет в SPEC_VALIDATED.md v1.1.
//   Спецификация заканчивается на FR-20 (SOSService).
//   Тесты написаны по фактическим требованиям MainScreen: FR-17, FR-18, FR-19.
//
// СТАТУС: 🔴 RED — новые требования FR-17/FR-18/FR-19 не реализованы в MainScreen.
//
// Архитектурный контракт:
//   MainScreen._MainScreenState:
//     - Загружает userId И userName в initState (через UserService.getUserName())
//     - Показывает имя (Key('user_name_display')) над ID (Key('user_id_display'))
//       только если имя непустое
//     - Кнопка Key('edit_name_button') всегда видна в карточке "My ID"
//     - По нажатию Edit Name: showDialog(AlertDialog(key: Key('edit_name_dialog')))
//       - TextField key: Key('edit_name_field'), предзаполнен _userName
//       - Кнопка Confirm key: Key('edit_name_confirm_button')
//           disabled (onPressed=null) если trim().isEmpty, enabled иначе
//       - Кнопка Cancel key: Key('edit_name_cancel_button')
//     - По Confirm: UserService.saveUserName(trimmedName), setState(_userName=trimmedName)
//       Диалог закрывается, карточка обновляется БЕЗ Navigator.pushReplacement
//     - При Supabase ошибке: имя сохраняется локально, показывается SnackBar
//
// Запуск:
//   flutter test tests/unit/main_screen/main_screen_test.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/screens/main_screen.dart';
import 'package:emergency_app/services/user_service.dart';

import 'mocks/test_helpers.dart';

// ---------------------------------------------------------------------------
// Вспомогательная: рендерит MainScreen и ждёт завершения initState
// ---------------------------------------------------------------------------
Future<void> pumpMainScreen(WidgetTester tester) async {
  await tester.pumpWidget(buildMainScreenTestApp());
  await tester.pumpAndSettle(); // ждём _loadUserData() завершения
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
  // FR-17 | AC-04 | Отображение имени пользователя
  // ==========================================================================
  group('FR-17 | AC-04 | Отображение имени пользователя в карточке My ID', () {
    testWidgets(
      '[AC-04] given user_name = "Alice" и userId = "ABCD1234" '
      'when MainScreen открыт '
      'then "Alice" отображается над "ABCD1234" в карточке My ID',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        expect(
          find.byKey(kUserNameDisplay),
          findsOneWidget,
          reason: 'AC-04: виджет с именем пользователя должен быть виден',
        );
        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Alice'),
            reason: 'AC-04: имя "Alice" отображается в карточке');

        expect(
          find.byKey(kUserIdDisplay),
          findsOneWidget,
          reason: 'User ID должен быть виден под именем',
        );
        final idWidget = tester.widget<Text>(find.byKey(kUserIdDisplay));
        expect(idWidget.data, equals('ABCD1234'));
      },
    );

    testWidgets(
      'given user_name не установлен '
      'when MainScreen открыт '
      'then виджет имени не отображается (только ID)',
      (tester) async {
        await initPrefsWithoutName(userId: 'ABCD1234');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        expect(
          find.byKey(kUserNameDisplay),
          findsNothing,
          reason:
              'FR-17: имя отображается ТОЛЬКО если установлено; '
              'при отсутствии имени виджет kUserNameDisplay не должен быть в дереве',
        );
        // ID всё равно виден
        expect(find.byKey(kUserIdDisplay), findsOneWidget);
      },
    );

    testWidgets(
      'given user_name = "Алиса" (Unicode) '
      'when MainScreen открыт '
      'then "Алиса" отображается корректно',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Алиса');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Алиса'));
      },
    );

    testWidgets(
      'given user_name = 50 символов (максимальное имя) '
      'when MainScreen открыт '
      'then полное имя отображается без усечения',
      (tester) async {
        final longName = 'B' * 50;
        await initMainScreenPrefs(userId: 'ABCD1234', userName: longName);
        setupUserServiceMock();

        await pumpMainScreen(tester);

        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals(longName),
            reason: 'Имя из 50 символов отображается без усечения');
      },
    );

    testWidgets(
      'given user_name = "" (пустая строка в prefs) '
      'when MainScreen открыт '
      'then виджет имени не отображается',
      (tester) async {
        // Явно сохраняем пустую строку
        SharedPreferences.setMockInitialValues({
          'myUserId': 'ABCD1234',
          'user_name': '',
        });
        setupUserServiceMock();

        await pumpMainScreen(tester);

        expect(find.byKey(kUserNameDisplay), findsNothing,
            reason: 'Пустая строка в user_name = имя не установлено → не показываем');
      },
    );

    testWidgets(
      'given userId = "ABCD1234" '
      'when MainScreen открыт '
      'then userId отображается в карточке (существующее поведение не сломано)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        final idWidget = tester.widget<Text>(find.byKey(kUserIdDisplay));
        expect(idWidget.data, equals('ABCD1234'),
            reason: 'Существующее поведение: userId всегда виден в карточке');
      },
    );
  });

  // ==========================================================================
  // FR-18 | Кнопка "Edit Name"
  // ==========================================================================
  group('FR-18 | Кнопка "Edit Name" в карточке My ID', () {
    testWidgets(
      '[AC-04] given user_name = "Alice" установлен '
      'when MainScreen открыт '
      'then кнопка "Edit Name" присутствует в карточке',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        expect(find.byKey(kEditNameButton), findsOneWidget,
            reason: 'AC-04: кнопка "Edit Name" должна быть в карточке My ID');
      },
    );

    testWidgets(
      'given user_name НЕ установлен '
      'when MainScreen открыт '
      'then кнопка "Edit Name" всё равно присутствует '
      '(чтобы пользователь мог задать имя без WelcomeScreen)',
      (tester) async {
        await initPrefsWithoutName(userId: 'ABCD1234');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        expect(find.byKey(kEditNameButton), findsOneWidget,
            reason: 'Edit Name доступна даже без установленного имени');
      },
    );

    testWidgets(
      'given MainScreen открыт '
      'when кнопка Edit Name tap-able '
      'then она нажимаема (onPressed не null)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        // Проверяем через нажатие — кнопка не должна выбросить исключение
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        // Диалог должен открыться
        expect(find.byKey(kEditNameDialog), findsOneWidget);
      },
    );
  });

  // ==========================================================================
  // FR-19 | AC-05 | Диалог: открытие и предзаполнение
  // ==========================================================================
  group('FR-19 | AC-05 | Диалог редактирования имени: открытие', () {
    testWidgets(
      '[AC-05] given user_name = "Alice" '
      'when нажата кнопка "Edit Name" '
      'then диалог открывается с TextField, предзаполненным "Alice"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        expect(find.byKey(kEditNameDialog), findsOneWidget,
            reason: 'AC-05: диалог должен открыться');

        final field = tester.widget<TextField>(find.byKey(kEditNameField));
        expect(
          field.controller?.text ?? '',
          equals('Alice'),
          reason: 'AC-05: TextField предзаполнен текущим именем "Alice"',
        );
      },
    );

    testWidgets(
      'given user_name не установлен '
      'when нажата кнопка "Edit Name" '
      'then диалог открывается с пустым TextField',
      (tester) async {
        await initPrefsWithoutName(userId: 'ABCD1234');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        expect(find.byKey(kEditNameDialog), findsOneWidget);
        final field = tester.widget<TextField>(find.byKey(kEditNameField));
        expect(field.controller?.text ?? '', isEmpty,
            reason: 'Без установленного имени поле диалога пустое');
      },
    );

    testWidgets(
      'given диалог открыт '
      'when пользователь нажимает Cancel '
      'then диалог закрывается',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kEditNameCancelButton));
        await tester.pumpAndSettle();

        expect(find.byKey(kEditNameDialog), findsNothing,
            reason: 'После Cancel диалог должен закрыться');
      },
    );

    testWidgets(
      'given диалог открыт '
      'when присутствуют кнопки Confirm и Cancel '
      'then обе кнопки видны',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        expect(find.byKey(kEditNameConfirmButton), findsOneWidget);
        expect(find.byKey(kEditNameCancelButton), findsOneWidget);
      },
    );
  });

  // ==========================================================================
  // FR-19 | AC-18 | Диалог: валидация (кнопка Confirm)
  // ==========================================================================
  group('FR-19 | AC-18 | Диалог: валидация кнопки подтверждения', () {
    testWidgets(
      '[AC-18] given диалог открыт с именем "Alice", поле очищено '
      'when поле пустое '
      'then кнопка Confirm disabled (onPressed = null)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        // Очищаем поле
        await tester.enterText(find.byKey(kEditNameField), '');
        await tester.pump();

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(
          confirmBtn.onPressed,
          isNull,
          reason: 'AC-18: пустое поле → кнопка подтверждения disabled',
        );
      },
    );

    testWidgets(
      '[AC-18] given поле содержит только пробелы " " '
      'when trim() = "" '
      'then Confirm disabled',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), '   ');
        await tester.pump();

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(confirmBtn.onPressed, isNull,
            reason: 'AC-18: пробелы → trim() = "" → Confirm disabled');
      },
    );

    testWidgets(
      'given поле диалога содержит "Bob" '
      'then Confirm enabled (onPressed != null)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(confirmBtn.onPressed, isNotNull,
            reason: 'Непустое имя "Bob" → Confirm enabled');
      },
    );

    testWidgets(
      'given поле содержит " Bob " (пробелы вокруг) '
      'then Confirm enabled (trim() = "Bob" — не пустое)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), ' Bob ');
        await tester.pump();

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(confirmBtn.onPressed, isNotNull,
            reason: '" Bob " → trim() непуст → Confirm enabled');
      },
    );

    testWidgets(
      'given поле предзаполнено "Alice" (при открытии диалога) '
      'when диалог только открылся '
      'then Confirm enabled (текущее имя валидно)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        // Сразу после открытия — имя "Alice" предзаполнено → Confirm enabled
        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(confirmBtn.onPressed, isNotNull,
            reason: 'Предзаполненное имя → кнопка Confirm доступна сразу');
      },
    );

    testWidgets(
      'given диалог открыт без имени (user_name не установлен) '
      'when поле пустое при открытии '
      'then Confirm disabled сразу (имя не задано)',
      (tester) async {
        await initPrefsWithoutName(userId: 'ABCD1234');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(kEditNameConfirmButton),
        );
        expect(confirmBtn.onPressed, isNull,
            reason: 'Пустое поле при открытии → Confirm disabled');
      },
    );
  });

  // ==========================================================================
  // FR-19 | AC-06 | Диалог: сохранение и обновление карточки
  // ==========================================================================
  group('FR-19 | AC-06 | Диалог: подтверждение и обновление', () {
    testWidgets(
      '[AC-06] given диалог открыт с именем "Alice", введено "Bob" '
      'when Confirm нажат '
      'then карточка My ID немедленно показывает "Bob" (без перезапуска экрана)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();

        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        // Диалог закрыт
        expect(find.byKey(kEditNameDialog), findsNothing,
            reason: 'После Confirm диалог должен закрыться');

        // Карточка обновлена
        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(
          nameWidget.data,
          equals('Bob'),
          reason: 'AC-06: карточка немедленно показывает новое имя "Bob"',
        );
      },
    );

    testWidgets(
      '[AC-06] given "Bob" подтверждён '
      'when диалог закрылся '
      'then SharedPreferences содержит user_name = "Bob"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_name'), equals('Bob'),
            reason: 'AC-06: SharedPreferences обновлён через UserService.saveUserName');
      },
    );

    testWidgets(
      '[AC-06] given "Bob" подтверждён '
      'when UserService.saveUserName вызывается '
      'then Supabase получает userId = "ABCD1234" и name = "Bob"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');

        final captured = <Map<String, String>>[];
        setupUserServiceMock(capturedCalls: captured);

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        expect(captured.length, equals(1),
            reason: 'AC-06: UserService.saveUserName вызывается ровно 1 раз');
        expect(captured.first['userId'], equals('ABCD1234'));
        expect(captured.first['name'], equals('Bob'));
      },
    );

    testWidgets(
      'given " Bob " (пробелы вокруг) подтверждено '
      'when сохранение выполняется '
      'then сохраняется "Bob" (с trim()), карточка показывает "Bob"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');

        final captured = <Map<String, String>>[];
        setupUserServiceMock(capturedCalls: captured);

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), ' Bob ');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        expect(captured.first['name'], equals('Bob'),
            reason: 'Имя должно сохраняться с trim()');

        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Bob'));
      },
    );

    testWidgets(
      'given Cancel нажат после изменения имени с "Alice" на "Bob" '
      'when диалог закрылся '
      'then карточка всё ещё показывает "Alice" (изменения не применены)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();

        // Отмена
        await tester.tap(find.byKey(kEditNameCancelButton));
        await tester.pumpAndSettle();

        // Карточка не изменилась
        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(
          nameWidget.data,
          equals('Alice'),
          reason: 'Cancel не изменяет имя в карточке',
        );
      },
    );

    testWidgets(
      'given Cancel нажат после изменения '
      'when SharedPreferences проверяются '
      'then user_name не изменился',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');

        final captured = <Map<String, String>>[];
        setupUserServiceMock(capturedCalls: captured);

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameCancelButton));
        await tester.pumpAndSettle();

        expect(captured, isEmpty,
            reason: 'Cancel → UserService.saveUserName не вызывался');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_name'), equals('Alice'),
            reason: 'Cancel → SharedPreferences не изменился');
      },
    );

    testWidgets(
      '[AC-18] given поле очищено в диалоге, нажата Cancel '
      'when диалог закрылся '
      'then текущее имя "Alice" остаётся без изменений',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        // Очищаем поле (Confirm disabled) и жмём Cancel
        await tester.enterText(find.byKey(kEditNameField), '');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameCancelButton));
        await tester.pumpAndSettle();

        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Alice'),
            reason:
                'AC-18: очищенное поле + Cancel → имя в карточке остаётся "Alice"');
      },
    );

    testWidgets(
      'given имя "Alice" → "Bob" подтверждено '
      'when диалог снова открывается '
      'then поле предзаполнено обновлённым именем "Bob"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        // Первое редактирование
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        // Второе открытие диалога
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byKey(kEditNameField));
        expect(field.controller?.text, equals('Bob'),
            reason:
                'AC-05: при повторном открытии диалог предзаполнен '
                'актуальным именем "Bob" (а не прежним "Alice")');
      },
    );
  });

  // ==========================================================================
  // FR-19 | Supabase ошибка при сохранении — локальное сохранение приоритетно
  // ==========================================================================
  group('FR-19 | Supabase ошибка при Edit Name', () {
    testWidgets(
      'given Supabase бросает исключение при saveUserName '
      'when "Bob" подтверждён '
      'then карточка всё равно показывает "Bob" (SharedPreferences сохранено)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock(supabaseError: Exception('Network error'));

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        // Карточка обновляется несмотря на ошибку Supabase
        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Bob'),
            reason:
                'NFR-06: SharedPreferences сохраняется до Supabase; '
                'при ошибке Supabase карточка всё равно показывает новое имя');
      },
    );

    testWidgets(
      'given Supabase ошибка при saveUserName '
      'when "Bob" подтверждён '
      'then SharedPreferences содержит user_name = "Bob"',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock(supabaseError: Exception('Network error'));

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_name'), equals('Bob'),
            reason: 'NFR-06: SharedPreferences обновлён даже при ошибке Supabase');
      },
    );

    testWidgets(
      'given Supabase ошибка при saveUserName '
      'when "Bob" подтверждён '
      'then SnackBar с предупреждением отображается',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock(supabaseError: Exception('Offline'));

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget,
            reason:
                'При ошибке Supabase показывается SnackBar-предупреждение; '
                'переход на другой экран не блокируется');
      },
    );

    testWidgets(
      'given Supabase ошибка '
      'when saveUserName завершается с ошибкой '
      'then приложение не падает (NFR-04)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock(supabaseError: Exception('Critical DB error'));

        await pumpMainScreen(tester);
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();

        // Не должно выбросить исключение
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        // Экран всё ещё доступен
        expect(find.byType(MainScreen), findsOneWidget,
            reason: 'NFR-04: ошибка Supabase не крашит MainScreen');
      },
    );
  });

  // ==========================================================================
  // FR-17 | Обновление карточки без перезапуска экрана
  // ==========================================================================
  group('FR-17 | Обновление карточки без перезапуска', () {
    testWidgets(
      'given имя обновлено с "Alice" на "Bob" '
      'when карточка My ID рендерится '
      'then MainScreen НЕ перезапускался (Navigator стек не изменился)',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        final observer = _TestNavigatorObserver();
        await tester.pumpWidget(MaterialApp(
          navigatorObservers: [observer],
          home: MainScreen(updateLocale: (_) {}),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        // После сохранения имени никаких pushReplacement / push не должно быть
        expect(observer.replacedRoutes, isEmpty,
            reason:
                'AC-06: карточка обновляется через setState, '
                'а не через Navigator.pushReplacement');
        expect(observer.pushedRoutes.length, equals(1),
            reason: 'Единственный push — это начальный роут MainScreen');

        // Имя в карточке обновилось
        final nameWidget = tester.widget<Text>(find.byKey(kUserNameDisplay));
        expect(nameWidget.data, equals('Bob'));
      },
    );

    testWidgets(
      'given имя изменяется несколько раз '
      'when каждый раз подтверждается '
      'then карточка каждый раз показывает актуальное имя',
      (tester) async {
        await initMainScreenPrefs(userId: 'ABCD1234', userName: 'Alice');
        setupUserServiceMock();

        await pumpMainScreen(tester);

        // Первое изменение: Alice → Bob
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(kEditNameField), 'Bob');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        expect(tester.widget<Text>(find.byKey(kUserNameDisplay)).data, equals('Bob'));

        // Второе изменение: Bob → Charlie
        await tester.tap(find.byKey(kEditNameButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(kEditNameField), 'Charlie');
        await tester.pump();
        await tester.tap(find.byKey(kEditNameConfirmButton));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.byKey(kUserNameDisplay)).data,
          equals('Charlie'),
          reason: 'Карточка обновляется при каждом подтверждении',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Вспомогательный Navigator Observer для проверки навигации
// ---------------------------------------------------------------------------
class _TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> replacedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replacedRoutes.add(newRoute);
  }
}
