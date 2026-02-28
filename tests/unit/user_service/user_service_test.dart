// ============================================================
// UserService — Unit Tests
// ============================================================
// Покрываемые требования:
//   FR-01 — hasUserName(): проверка наличия имени в SharedPreferences
//   FR-02 — getUserName(): получение имени из SharedPreferences
//   FR-03 — saveUserName(): сохранение имени локально + Supabase upsert
//   FR-04 — Условие роутинга: нет имени → WelcomeScreen (зависит от FR-01)
//   NFR-06 — SharedPreferences сохраняется всегда, независимо от Supabase
//
// СТАТУС: 🔴 RED — все тесты провалятся до реализации методов в UserService.
// Это корректное ожидаемое состояние при TDD.
//
// Зависимости для запуска (добавить в pubspec.yaml dev_dependencies):
//   mocktail: ^0.3.0
//
// Запуск:
//   flutter test tests/unit/user_service/user_service_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/services/user_service.dart';

import 'mocks/mock_supabase_service.dart';

// ---------------------------------------------------------------------------
// Константы — SharedPreferences ключи (должны совпадать с реализацией)
// ---------------------------------------------------------------------------
const String _kUserNameKey = 'user_name';
const String _kUserIdKey = 'myUserId';

// ---------------------------------------------------------------------------
// Вспомогательная функция: инициализировать SharedPreferences с тестовыми
// данными и сбросить все предыдущие значения.
// ---------------------------------------------------------------------------
Future<void> _initPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
}

void main() {
  // Мок Supabase-слоя — будет передаваться в UserService через override
  final mockSupabase = MockSupabasePersistence();

  setUp(() {
    mockSupabase.reset();
    SharedPreferences.setMockInitialValues({});

    // Внедряем мок Supabase в UserService.
    // Реализация должна поддерживать @visibleForTesting метод:
    //   UserService.setSupabaseSaveOverride(mockSupabase.updateUserName);
    UserService.setSupabaseSaveOverride(mockSupabase.updateUserName);
  });

  tearDown(() {
    // Очищаем override после каждого теста
    UserService.setSupabaseSaveOverride(null);
  });

  // ==========================================================================
  // FR-01: hasUserName()
  // ==========================================================================
  group('FR-01 | hasUserName()', () {
    test(
      'given SharedPreferences is empty '
      'when hasUserName is called '
      'then returns false',
      () async {
        // Arrange
        await _initPrefs({});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isFalse);
      },
    );

    test(
      'given user_name key does not exist in SharedPreferences '
      'when hasUserName is called '
      'then returns false',
      () async {
        // Arrange — другие ключи есть, user_name нет
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isFalse);
      },
    );

    test(
      'given user_name is stored as empty string "" '
      'when hasUserName is called '
      'then returns false (пустая строка = имя не установлено)',
      () async {
        // Arrange
        // EC-01: пустая строка не должна считаться валидным именем
        await _initPrefs({_kUserNameKey: ''});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isFalse);
      },
    );

    test(
      'given user_name is set to a non-empty value "Alice" '
      'when hasUserName is called '
      'then returns true',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'Alice'});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isTrue);
      },
    );

    test(
      'given user_name is a single character "A" '
      'when hasUserName is called '
      'then returns true (минимально допустимое имя)',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'A'});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isTrue);
      },
    );

    test(
      'given user_name is exactly 50 characters (максимальная длина, NFR-05) '
      'when hasUserName is called '
      'then returns true',
      () async {
        // Arrange
        final maxLengthName = 'A' * 50;
        await _initPrefs({_kUserNameKey: maxLengthName});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isTrue);
      },
    );

    test(
      'given user_name contains unicode characters "Алиса" '
      'when hasUserName is called '
      'then returns true',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'Алиса'});

        // Act
        final result = await UserService.hasUserName();

        // Assert
        expect(result, isTrue);
      },
    );

    // ---- FR-04: роутинг зависит от hasUserName() -------------------------

    test(
      '[FR-04] given имя не установлено '
      'when hasUserName is called '
      'then возвращает false — условие для показа WelcomeScreen выполнено',
      () async {
        // Arrange
        await _initPrefs({});

        // Act
        final shouldShowWelcome = !(await UserService.hasUserName());

        // Assert
        expect(shouldShowWelcome, isTrue,
            reason: 'Пользователь без имени должен попасть на WelcomeScreen');
      },
    );

    test(
      '[FR-04] given имя установлено "Bob" '
      'when hasUserName is called '
      'then возвращает true — условие для показа MainScreen выполнено',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'Bob'});

        // Act
        final shouldShowMain = await UserService.hasUserName();

        // Assert
        expect(shouldShowMain, isTrue,
            reason: 'Пользователь с именем должен попасть на MainScreen');
      },
    );
  });

  // ==========================================================================
  // FR-02: getUserName()
  // ==========================================================================
  group('FR-02 | getUserName()', () {
    test(
      'given SharedPreferences is empty '
      'when getUserName is called '
      'then returns null',
      () async {
        // Arrange
        await _initPrefs({});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'given user_name key is absent (есть другие ключи) '
      'when getUserName is called '
      'then returns null',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, isNull);
      },
    );

    test(
      'given user_name is stored as empty string "" '
      'when getUserName is called '
      'then returns null (пустая строка = имя не установлено)',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: ''});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, isNull,
            reason: 'Пустая строка должна интерпретироваться как отсутствие имени');
      },
    );

    test(
      'given user_name is "Alice" '
      'when getUserName is called '
      'then returns "Alice" (точное значение)',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'Alice'});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, equals('Alice'));
      },
    );

    test(
      'given user_name contains unicode "Алиса" '
      'when getUserName is called '
      'then returns "Алиса" без изменений',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: 'Алиса'});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, equals('Алиса'));
      },
    );

    test(
      'given user_name contains special characters "O\'Brien 😊" '
      'when getUserName is called '
      'then returns значение без изменений (EC-09)',
      () async {
        // Arrange
        await _initPrefs({_kUserNameKey: "O'Brien 😊"});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, equals("O'Brien 😊"));
      },
    );

    test(
      'given user_name is exactly 50 characters '
      'when getUserName is called '
      'then returns полное значение без усечения',
      () async {
        // Arrange
        final maxName = 'B' * 50;
        await _initPrefs({_kUserNameKey: maxName});

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, equals(maxName));
        expect(result!.length, equals(50));
      },
    );

    test(
      'given user_name is "Alice" and userId is "ABCD1234" (оба ключа в prefs) '
      'when getUserName is called '
      'then returns только имя "Alice", не userId',
      () async {
        // Arrange
        await _initPrefs({
          _kUserIdKey: 'ABCD1234',
          _kUserNameKey: 'Alice',
        });

        // Act
        final result = await UserService.getUserName();

        // Assert
        expect(result, equals('Alice'));
        expect(result, isNot(equals('ABCD1234')));
      },
    );
  });

  // ==========================================================================
  // FR-03: saveUserName()
  // ==========================================================================
  group('FR-03 | saveUserName()', () {
    // ---- SharedPreferences persistence -----------------------------------

    test(
      'given пустые SharedPreferences '
      'when saveUserName("Alice") вызван '
      'then user_name сохранён в SharedPreferences с ключом "user_name"',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        final prefs = await SharedPreferences.getInstance();

        // Act
        await UserService.saveUserName('Alice');

        // Assert
        expect(prefs.getString(_kUserNameKey), equals('Alice'));
      },
    );

    test(
      'given сохранено имя "Alice" '
      'when saveUserName("Bob") вызван (обновление) '
      'then user_name обновлён до "Bob"',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234', _kUserNameKey: 'Alice'});
        final prefs = await SharedPreferences.getInstance();

        // Act
        await UserService.saveUserName('Bob');

        // Assert
        expect(prefs.getString(_kUserNameKey), equals('Bob'));
      },
    );

    test(
      'given saveUserName("Alice") вызван '
      'when после сохранения вызывается hasUserName() '
      'then возвращает true',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        await UserService.saveUserName('Alice');
        final hasName = await UserService.hasUserName();

        // Assert
        expect(hasName, isTrue);
      },
    );

    test(
      'given saveUserName("Alice") вызван '
      'when после сохранения вызывается getUserName() '
      'then возвращает "Alice"',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        await UserService.saveUserName('Alice');
        final name = await UserService.getUserName();

        // Assert
        expect(name, equals('Alice'));
      },
    );

    test(
      'given имя содержит unicode "Алиса" '
      'when saveUserName("Алиса") вызван '
      'then SharedPreferences содержит "Алиса" без изменений',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        final prefs = await SharedPreferences.getInstance();

        // Act
        await UserService.saveUserName('Алиса');

        // Assert
        expect(prefs.getString(_kUserNameKey), equals('Алиса'));
      },
    );

    // ---- Supabase interaction --------------------------------------------

    test(
      'given userId "ABCD1234" в SharedPreferences '
      'when saveUserName("Alice") вызван '
      'then Supabase update вызван ровно один раз',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        await UserService.saveUserName('Alice');

        // Assert
        expect(mockSupabase.wasCalledOnce, isTrue,
            reason: 'Supabase должен вызываться ровно один раз при сохранении');
      },
    );

    test(
      'given userId "ABCD1234" в SharedPreferences '
      'when saveUserName("Alice") вызван '
      'then Supabase update вызван с корректными userId и name',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        await UserService.saveUserName('Alice');

        // Assert
        expect(mockSupabase.calls.first['userId'], equals('ABCD1234'));
        expect(mockSupabase.calls.first['name'], equals('Alice'));
      },
    );

    test(
      'given userId существует '
      'when saveUserName("Bob") вызван после saveUserName("Alice") '
      'then Supabase вызван дважды, последний с "Bob"',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Act
        await UserService.saveUserName('Alice');
        await UserService.saveUserName('Bob');

        // Assert
        expect(mockSupabase.calls.length, equals(2));
        expect(mockSupabase.calls.last['name'], equals('Bob'));
      },
    );

    // ---- NFR-06: SharedPreferences сохраняется независимо от Supabase ---

    test(
      '[NFR-06] given Supabase выбрасывает исключение (нет сети) '
      'when saveUserName("Alice") вызван '
      'then SharedPreferences всё равно содержит "Alice"',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        mockSupabase.errorToThrow = Exception('Network error');
        final prefs = await SharedPreferences.getInstance();

        // Act — ошибка ожидается, но SharedPreferences должен быть обновлён
        try {
          await UserService.saveUserName('Alice');
        } catch (_) {
          // Ошибка от Supabase ожидается и перехватывается
        }

        // Assert
        expect(
          prefs.getString(_kUserNameKey),
          equals('Alice'),
          reason:
              'NFR-06: локальное сохранение не должно зависеть от Supabase',
        );
      },
    );

    test(
      '[NFR-06] given Supabase выбрасывает исключение '
      'when saveUserName("Alice") вызван '
      'then после вызова hasUserName() возвращает true (имя доступно локально)',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        mockSupabase.errorToThrow = Exception('Timeout');

        // Act
        try {
          await UserService.saveUserName('Alice');
        } catch (_) {}

        // Assert
        final hasName = await UserService.hasUserName();
        expect(hasName, isTrue,
            reason:
                'NFR-06: имя доступно локально даже при сбое синхронизации');
      },
    );

    test(
      '[NFR-06] given Supabase выбрасывает исключение '
      'when saveUserName("Alice") вызван '
      'then исключение пробрасывается вызывающему коду (для показа Snackbar)',
      () async {
        // Arrange
        // EC-03: вызывающий код должен получить исключение, чтобы показать
        // предупреждающий Snackbar.
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        mockSupabase.errorToThrow = Exception('Network unavailable');

        // Act & Assert
        expect(
          () async => await UserService.saveUserName('Alice'),
          throwsA(isA<Exception>()),
          reason:
              'Ошибка Supabase должна пробрасываться вызывающему коду '
              'для отображения Snackbar-предупреждения (EC-03)',
        );
      },
    );

    test(
      'given Supabase недоступен '
      'when saveUserName("Alice") вызван '
      'then SharedPreferences обновлён ДО вызова Supabase '
      '(гарантия локального сохранения независимо от порядка)',
      () async {
        // Arrange
        // Эмулируем немедленный сбой Supabase
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        mockSupabase.errorToThrow = Exception('Connection refused');
        final prefs = await SharedPreferences.getInstance();

        // Act
        try {
          await UserService.saveUserName('Alice');
        } catch (_) {}

        // Assert — SharedPreferences обновлён несмотря на сбой
        final stored = prefs.getString(_kUserNameKey);
        expect(stored, equals('Alice'),
            reason: 'SharedPreferences должен сохраняться до вызова Supabase');
      },
    );

    // ---- Граничные значения ----------------------------------------------

    test(
      'given имя из 50 символов (максимальная допустимая длина, NFR-05) '
      'when saveUserName вызван '
      'then сохраняется полностью без усечения',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        final maxName = 'X' * 50;
        final prefs = await SharedPreferences.getInstance();

        // Act
        await UserService.saveUserName(maxName);

        // Assert
        expect(prefs.getString(_kUserNameKey), equals(maxName));
        expect(prefs.getString(_kUserNameKey)!.length, equals(50));
      },
    );

    test(
      'given имя содержит специальные символы "O\'Brien" '
      'when saveUserName вызван '
      'then сохраняется без изменений (EC-09)',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        final prefs = await SharedPreferences.getInstance();

        // Act
        await UserService.saveUserName("O'Brien");

        // Assert
        expect(prefs.getString(_kUserNameKey), equals("O'Brien"));
      },
    );

    test(
      'given userId ещё не создан в SharedPreferences '
      'when saveUserName("Alice") вызван '
      'then выбрасывает StateError или ArgumentError '
      '(userId должен существовать к моменту вызова saveUserName)',
      () async {
        // Arrange
        // Имитируем ситуацию: WelcomeScreen вызван до инициализации userId
        // В корректном флоу userId создаётся в main.dart до показа экранов.
        await _initPrefs({}); // нет ни user_name, ни userId

        // Act & Assert
        // Реализация должна выбросить если userId отсутствует,
        // поскольку без userId невозможно выполнить Supabase update.
        expect(
          () async => await UserService.saveUserName('Alice'),
          throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
          reason:
              'saveUserName не может работать без userId — '
              'это указывает на ошибку в порядке инициализации',
        );
      },
    );
  });

  // ==========================================================================
  // Интеграция: hasUserName + getUserName + saveUserName
  // ==========================================================================
  group('Интеграция | цепочка hasUserName → saveUserName → getUserName', () {
    test(
      'given новый пользователь (нет имени) '
      'when saveUserName("Alice") → hasUserName() → getUserName() '
      'then состояние консистентно на всех уровнях',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});

        // Начальное состояние
        expect(await UserService.hasUserName(), isFalse);
        expect(await UserService.getUserName(), isNull);

        // Act
        await UserService.saveUserName('Alice');

        // Assert — состояние после сохранения
        expect(await UserService.hasUserName(), isTrue);
        expect(await UserService.getUserName(), equals('Alice'));
      },
    );

    test(
      'given пользователь с именем "Alice" '
      'when saveUserName("Charlie") (смена имени) '
      'then hasUserName() = true, getUserName() = "Charlie"',
      () async {
        // Arrange
        await _initPrefs({
          _kUserIdKey: 'ABCD1234',
          _kUserNameKey: 'Alice',
        });

        // Act
        await UserService.saveUserName('Charlie');

        // Assert
        expect(await UserService.hasUserName(), isTrue);
        expect(await UserService.getUserName(), equals('Charlie'));
      },
    );

    test(
      '[NFR-06] given Supabase недоступен при saveUserName '
      'when после сбоя вызывается getUserName() '
      'then имя доступно локально (приложение работает офлайн)',
      () async {
        // Arrange
        await _initPrefs({_kUserIdKey: 'ABCD1234'});
        mockSupabase.errorToThrow = Exception('No internet');

        // Act
        try {
          await UserService.saveUserName('Alice');
        } catch (_) {}

        // Assert
        expect(await UserService.getUserName(), equals('Alice'),
            reason: 'Имя доступно из SharedPreferences даже без синхронизации');
      },
    );
  });
}
