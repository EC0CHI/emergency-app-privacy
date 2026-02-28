// ============================================================
// GuardiansService — Unit Tests
// ============================================================
// Покрываемые требования:
//   FR-08  — findUserName(userId): SELECT user_name FROM users WHERE user_id = ?
//   NFR-02 — Таймаут запроса ≤ 5 секунд
//   EC-05  — Неполный ID (< 8 символов) — запрос выполняется, возвращает null
//   EC-06  — Собственный userId — технически допустимо
//   EC-08  — Отсутствие колонки / ошибка Supabase → null, не падение
//   EC-12  — Legacy-пользователь с null user_name → null
//
// СТАТУС: 🔴 RED — GuardiansService не реализован.
//
// Архитектурный контракт:
//   GuardiansService должен поддерживать ДВА уровня инжекции для тестов:
//
//   1. setSupabaseQueryOverride — подменяет Supabase-запрос (тест логики service):
//      static Future<Map<String,dynamic>?> Function(String userId)?
//          _supabaseQueryOverride;
//      @visibleForTesting
//      static void setSupabaseQueryOverride(
//          Future<Map<String,dynamic>?> Function(String)? fn)
//
//   2. setFindUserNameOverride — подменяет весь findUserName (для widget-тестов):
//      static Future<String?> Function(String userId)?
//          _findUserNameOverride;
//      @visibleForTesting
//      static void setFindUserNameOverride(
//          Future<String?> Function(String)? fn)
//
//   Реализация findUserName:
//   static Future<String?> findUserName(String userId) async {
//     if (_findUserNameOverride != null) return _findUserNameOverride!(userId);
//     try {
//       final result = (_supabaseQueryOverride != null)
//           ? await _supabaseQueryOverride!(userId)
//                 .timeout(const Duration(seconds: 5))
//           : await Supabase.instance.client
//                 .from('users')
//                 .select('user_name')
//                 .eq('user_id', userId)
//                 .maybeSingle()
//                 .timeout(const Duration(seconds: 5));
//       if (result == null) return null;
//       final name = result['user_name'] as String?;
//       return (name == null || name.isEmpty) ? null : name;
//     } catch (_) {
//       return null;
//     }
//   }
//
// Запуск:
//   flutter test tests/unit/guardians/guardians_service_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_app/services/guardians_service.dart'; // 🔴 не существует

void main() {
  setUp(() {
    GuardiansService.setSupabaseQueryOverride(null);
  });

  tearDown(() {
    GuardiansService.setSupabaseQueryOverride(null);
  });

  // ==========================================================================
  // FR-08 | findUserName — основная логика извлечения имени
  // ==========================================================================
  group('FR-08 | findUserName — базовые сценарии', () {
    test(
      'given Supabase возвращает user_name = "Charlie" '
      'when findUserName("ABCD1234") '
      'then returns "Charlie"',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': 'Charlie'},
        );

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, equals('Charlie'));
      },
    );

    test(
      'given Supabase возвращает user_name = "Алиса" (Unicode) '
      'when findUserName("ABCD1234") '
      'then returns "Алиса" без изменений',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': 'Алиса'},
        );

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, equals('Алиса'));
      },
    );

    test(
      'given Supabase возвращает user_name = "A-B" (спецсимволы) '
      'when findUserName '
      'then возвращает строку без изменений',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': "O'Brien"},
        );

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, equals("O'Brien"));
      },
    );

    test(
      'given Supabase возвращает null (строка не найдена) '
      'when findUserName("ZZZZZZZZ") '
      'then returns null',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async => null);

        final result = await GuardiansService.findUserName('ZZZZZZZZ');

        expect(result, isNull,
            reason: 'Пользователь не найден в Supabase → null');
      },
    );

    test(
      '[EC-12] given Supabase возвращает строку с user_name = null (legacy-пользователь) '
      'when findUserName '
      'then returns null',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': null},
        );

        final result = await GuardiansService.findUserName('LEGACY01');

        expect(
          result,
          isNull,
          reason:
              'EC-12: legacy-пользователь без имени — user_name = null → findUserName returns null',
        );
      },
    );

    test(
      'given Supabase возвращает строку с user_name = "" (пустая строка) '
      'when findUserName '
      'then returns null (пустая строка = имя не установлено)',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': ''},
        );

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, isNull,
            reason: 'Пустая строка в user_name трактуется как отсутствие имени');
      },
    );
  });

  // ==========================================================================
  // FR-08 | findUserName — корректная передача userId в запрос
  // ==========================================================================
  group('FR-08 | findUserName — передача userId', () {
    test(
      'given findUserName вызван с "ABCD1234" '
      'when Supabase-запрос выполняется '
      'then запрос содержит именно этот userId',
      () async {
        String? capturedUserId;
        GuardiansService.setSupabaseQueryOverride((userId) async {
          capturedUserId = userId;
          return {'user_name': 'Alice'};
        });

        await GuardiansService.findUserName('ABCD1234');

        expect(capturedUserId, equals('ABCD1234'),
            reason: 'Service должен передать точный userId в запрос без изменений');
      },
    );

    test(
      'given findUserName вызван с "ZX987654" (другой userId) '
      'when запрос выполняется '
      'then запрос содержит "ZX987654"',
      () async {
        String? capturedUserId;
        GuardiansService.setSupabaseQueryOverride((userId) async {
          capturedUserId = userId;
          return null;
        });

        await GuardiansService.findUserName('ZX987654');

        expect(capturedUserId, equals('ZX987654'));
      },
    );

    test(
      '[EC-05] given userId = "ABC" (3 символа, неполный ID) '
      'when findUserName вызван '
      'then запрос выполняется (валидация ID — не задача service), возвращает null',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async => null);

        final result = await GuardiansService.findUserName('ABC');

        expect(result, isNull,
            reason:
                'EC-05: неполный ID → Supabase не найдёт запись → null. '
                'Валидация формата ID — ответственность UI, не service.');
      },
    );

    test(
      '[EC-06] given userId = собственный ID пользователя '
      'when findUserName вызван '
      'then возвращает собственное имя (service не ограничивает self-lookup)',
      () async {
        GuardiansService.setSupabaseQueryOverride(
          (_) async => {'user_name': 'SelfName'},
        );

        final result = await GuardiansService.findUserName('MYOWNID1');

        expect(result, equals('SelfName'),
            reason: 'EC-06: поиск собственного ID допустим на уровне service');
      },
    );
  });

  // ==========================================================================
  // EC-08 | Ошибки Supabase — graceful degradation (не крашить)
  // ==========================================================================
  group('EC-08 | Ошибки Supabase — возврат null без краша', () {
    test(
      'given Supabase бросает Exception("Network error") '
      'when findUserName вызван '
      'then возвращает null без краша',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async {
          throw Exception('Network error');
        });

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, isNull,
            reason: 'EC-08: любое исключение → null, приложение не падает');
      },
    );

    test(
      '[EC-08] given Supabase бросает StateError (колонка user_name отсутствует) '
      'when findUserName '
      'then returns null',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async {
          throw StateError('column "user_name" does not exist');
        });

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, isNull,
            reason: 'EC-08: отсутствие миграции → ошибка колонки → null');
      },
    );

    test(
      'given Supabase бросает исключение с сообщением "permission denied" (RLS) '
      'when findUserName '
      'then returns null',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async {
          throw Exception('permission denied for table users');
        });

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, isNull);
      },
    );

    test(
      'given Supabase бросает исключение для первого запроса '
      'when второй запрос (другой userId) выполняется нормально '
      'then второй возвращает корректный результат (ошибки изолированы)',
      () async {
        int callCount = 0;
        GuardiansService.setSupabaseQueryOverride((userId) async {
          callCount++;
          if (callCount == 1) throw Exception('error on first call');
          return {'user_name': 'Bob'};
        });

        final result1 = await GuardiansService.findUserName('ERROR001');
        final result2 = await GuardiansService.findUserName('BOB00001');

        expect(result1, isNull, reason: 'Первый вызов с ошибкой → null');
        expect(result2, equals('Bob'), reason: 'Второй вызов без ошибки → имя');
      },
    );
  });

  // ==========================================================================
  // NFR-02 | Таймаут — максимум 5 секунд
  // ==========================================================================
  group('NFR-02 | Таймаут при медленном ответе Supabase', () {
    test(
      'given Supabase отвечает через 6 секунд (> 5 sec timeout) '
      'when findUserName вызван '
      'then возвращает null после таймаута (не зависает)',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async {
          await Future.delayed(const Duration(seconds: 6));
          return {'user_name': 'Charlie'};
        });

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, isNull,
            reason: 'NFR-02: запрос > 5s должен завершаться null по таймауту');
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'given Supabase отвечает через 4 секунды (< 5 sec timeout) '
      'when findUserName вызван '
      'then возвращает имя (таймаут не сработал)',
      () async {
        GuardiansService.setSupabaseQueryOverride((_) async {
          await Future.delayed(const Duration(seconds: 4));
          return {'user_name': 'FastEnough'};
        });

        final result = await GuardiansService.findUserName('ABCD1234');

        expect(result, equals('FastEnough'),
            reason: 'NFR-02: запрос < 5s должен успешно вернуть результат');
      },
      timeout: const Timeout(Duration(seconds: 8)),
    );
  });
}
