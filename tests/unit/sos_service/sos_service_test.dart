// ============================================================
// SOSService — Unit Tests
// ============================================================
// Покрываемые требования:
//   FR-20  — Формирование сообщения SOS:
//              • имя установлено → "SOS Emergency from [Имя] ([ID])"
//              • имя не установлено → "SOS Emergency from [ID]"
//   AC-14  — "Alice" (ID "XY123456") → "SOS Emergency from Alice (XY123456)"
//   AC-15  — нет имени (ID "XY123456") → "SOS Emergency from XY123456"
//
// ⚠️  ЗАМЕЧАНИЕ ПО НУМЕРАЦИИ:
//   Пользователь указал FR-25, FR-26, FR-27 — таких требований в
//   SPEC_VALIDATED.md v1.1 нет. Спецификация заканчивается на FR-20.
//   Тесты написаны по фактическому требованию: FR-20.
//
// СТАТУС: 🔴 RED — SosService ещё не читает userName, формат сообщения устарел.
//
// Текущее состояние (до реализации):
//   message: 'Emergency alert from $myUserId'   ← НЕВЕРНО
//
// Ожидаемое (FR-20):
//   message: 'SOS Emergency from $userName ($userId)'  — если имя есть
//   message: 'SOS Emergency from $userId'              — если имени нет
//
// Архитектурный контракт — два уровня override для тестов:
//
//   // 1. Заменяет вызов Edge Function
//   static Future<Map<String,dynamic>> Function(List<String>, String)?
//       _edgeFunctionOverride;
//   @visibleForTesting
//   static void setEdgeFunctionOverride(
//       Future<Map<String,dynamic>> Function(List<String>, String)? fn)
//
//   // 2. Заменяет SupabaseService.getGuardianOneSignalIds()
//   static Future<List<String>> Function(List<String>)?
//       _getOneSignalIdsOverride;
//   @visibleForTesting
//   static void setGetOneSignalIdsOverride(
//       Future<List<String>> Function(List<String>)? fn)
//
//   Обновлённый sendSOS():
//   static Future<Map<String,dynamic>> sendSOS() async {
//     try {
//       final myUserId  = await UserService.getUserId();
//       final userName  = await UserService.getUserName();   // НОВЫЙ вызов
//       final guardians = await _getGuardianUserIds();
//       if (guardians.isEmpty) return {error};
//       final oneSignalIds = _getOneSignalIdsOverride != null
//           ? await _getOneSignalIdsOverride!(guardians)
//           : await SupabaseService.getGuardianOneSignalIds(guardians);
//       if (oneSignalIds.isEmpty) return {error};
//       final message = (userName != null && userName.isNotEmpty)
//           ? 'SOS Emergency from $userName ($myUserId)'
//           : 'SOS Emergency from $myUserId';
//       final result = _edgeFunctionOverride != null
//           ? await _edgeFunctionOverride!(oneSignalIds, message)
//           : await _callEdgeFunction(oneSignalIds, message);
//       return result['success'] == true
//           ? {'success': true, 'recipients': oneSignalIds.length}
//           : {'success': false, 'error': result['error'] ?? 'Unknown error'};
//     } catch (e) {
//       return {'success': false, 'error': e.toString()};
//     }
//   }
//
// Запуск:
//   flutter test tests/unit/sos_service/sos_service_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/services/sos_service.dart'; // существует

import 'mocks/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tearDownSosTest();
  });

  tearDown(() {
    tearDownSosTest();
  });

  // ==========================================================================
  // FR-20 | AC-14, AC-15 | Формирование сообщения SOS
  // ==========================================================================
  group('FR-20 | AC-14 AC-15 | Формат сообщения SOS', () {
    test(
      '[AC-14] given user_name = "Alice", userId = "XY123456" '
      'when sendSOS вызван '
      'then Edge Function получает message = "SOS Emergency from Alice (XY123456)"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from Alice (XY123456)'),
          reason:
              'AC-14: при наличии имени формат: "SOS Emergency from [Имя] ([ID])"',
        );
      },
    );

    test(
      '[AC-15] given user_name НЕ установлен, userId = "XY123456" '
      'when sendSOS вызван '
      'then Edge Function получает message = "SOS Emergency from XY123456"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: null, // имя не установлено
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from XY123456'),
          reason:
              'AC-15: без имени формат: "SOS Emergency from [ID]" — без скобок',
        );
      },
    );

    test(
      'given user_name = "" (пустая строка в prefs) '
      'when sendSOS вызван '
      'then message = "SOS Emergency from [ID]" (пустая строка = нет имени)',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: '', // явно пустая строка
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from XY123456'),
          reason: 'Пустая строка user_name трактуется как отсутствие имени',
        );
      },
    );

    test(
      'given user_name = "Алиса" (Unicode, кириллица) '
      'when sendSOS вызван '
      'then message = "SOS Emergency from Алиса (XY123456)"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Алиса',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from Алиса (XY123456)'),
        );
      },
    );

    test(
      'given user_name = "A" (1 символ, минимальное валидное имя) '
      'when sendSOS '
      'then message = "SOS Emergency from A (XY123456)"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'A',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from A (XY123456)'),
        );
      },
    );

    test(
      'given user_name = 50 символов (максимальное имя) '
      'when sendSOS '
      'then message содержит полное имя без усечения',
      () async {
        final longName = 'B' * 50;
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: longName,
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from $longName (XY123456)'),
          reason: '50-символьное имя передаётся в message без усечения',
        );
      },
    );

    test(
      'given user_name содержит спецсимволы "O\'Brien" '
      'when sendSOS '
      'then message = "SOS Emergency from O\'Brien (XY123456)"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: "O'Brien",
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals("SOS Emergency from O'Brien (XY123456)"),
        );
      },
    );

    test(
      'given user_name = "Alice", userId = "ABCD1234" (другой ID) '
      'when sendSOS '
      'then message содержит именно "ABCD1234", не "XY123456"',
      () async {
        // Проверка, что правильный userId подставляется в message
        final env = await setUpSosTest(
          userId: 'ABCD1234',
          userName: 'Alice',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from Alice (ABCD1234)'),
          reason: 'В сообщении используется userId текущего пользователя',
        );
      },
    );

    test(
      'given сообщение формируется '
      'when sendSOS '
      'then сообщение НЕ содержит устаревший префикс "Emergency alert from"',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: ['os_id_1'],
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastMessage,
          isNot(contains('Emergency alert from')),
          reason:
              'Регрессионная проверка: старый формат "Emergency alert from" '
              'должен быть заменён на "SOS Emergency from"',
        );
        expect(
          env.edgeFn.lastMessage,
          startsWith('SOS Emergency from'),
          reason: 'Все SOS-сообщения начинаются с "SOS Emergency from"',
        );
      },
    );
  });

  // ==========================================================================
  // Загрузка guardian IDs из SharedPreferences
  // ==========================================================================
  group('Guardian IDs | Загрузка из SharedPreferences', () {
    test(
      'given нет сохранённых хранителей (все слоты пустые) '
      'when sendSOS вызван '
      'then возвращается {success: false, error: "No guardians configured"}',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {}, // нет хранителей
          oneSignalIds: [],
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(
          result['error'],
          equals('No guardians configured'),
          reason: 'Без хранителей SOS не может быть отправлен',
        );
      },
    );

    test(
      'given все 5 слотов хранителей пусты '
      'when sendSOS '
      'then {success: false} — пустые строки не считаются хранителями',
      () async {
        // Явно записываем пустые строки в prefs
        SharedPreferences.setMockInitialValues({
          'myUserId': 'XY123456',
          'user_name': 'Alice',
          'guardian1': '',
          'guardian2': '',
          'guardian3': '',
          'guardian4': '',
          'guardian5': '',
        });
        final mock = MockEdgeFunction();
        SosService.setEdgeFunctionOverride(mock.call);
        SosService.setGetOneSignalIdsOverride((_) async => []);

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(result['error'], equals('No guardians configured'));
        expect(mock.callCount, equals(0),
            reason: 'Edge Function не должна вызываться при отсутствии хранителей');
      },
    );

    test(
      'given только guardian2 заполнен ("BBBB2222"), остальные пустые '
      'when sendSOS '
      'then только "BBBB2222" передаётся в OneSignal resolver',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {2: 'BBBB2222'}, // только слот 2
          oneSignalIds: ['os_bbbb'],
        );

        await SosService.sendSOS();

        expect(
          env.resolver.lastArgs,
          equals(['BBBB2222']),
          reason: 'Только непустые guardian IDs передаются в resolver',
        );
      },
    );

    test(
      'given guardian1 = "AAAA1111", guardian3 = "CCCC3333" (через слот) '
      'when sendSOS '
      'then оба ID передаются в OneSignal resolver',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'AAAA1111', 3: 'CCCC3333'},
          oneSignalIds: ['os_aaaa', 'os_cccc'],
        );

        await SosService.sendSOS();

        expect(
          env.resolver.lastArgs,
          containsAll(['AAAA1111', 'CCCC3333']),
        );
        expect(env.resolver.lastArgs?.length, equals(2));
      },
    );

    test(
      'given все 5 хранителей заполнены '
      'when sendSOS '
      'then все 5 IDs переданы в resolver',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {
            1: 'GRD11111',
            2: 'GRD22222',
            3: 'GRD33333',
            4: 'GRD44444',
            5: 'GRD55555',
          },
          oneSignalIds: ['os1', 'os2', 'os3', 'os4', 'os5'],
        );

        await SosService.sendSOS();

        expect(env.resolver.lastArgs?.length, equals(5));
      },
    );
  });

  // ==========================================================================
  // OneSignal IDs resolution
  // ==========================================================================
  group('OneSignal IDs | Получение из Supabase', () {
    test(
      'given ни один хранитель не установил приложение (OneSignal IDs пусты) '
      'when sendSOS '
      'then {success: false, error содержит "No active guardians found"}',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: [], // нет активных хранителей
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(
          (result['error'] as String).toLowerCase(),
          contains('no active guardians'),
          reason: 'Если ни у одного хранителя нет приложения — ошибка',
        );
        expect(env.edgeFn.callCount, equals(0),
            reason: 'Edge Function не вызывается при отсутствии OneSignal IDs');
      },
    );

    test(
      'given 3 хранителя из 5 имеют OneSignal IDs '
      'when sendSOS '
      'then Edge Function вызывается с 3 player_ids',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1', 2: 'G2', 3: 'G3', 4: 'G4', 5: 'G5'},
          oneSignalIds: ['os1', 'os2', 'os3'], // только 3 из 5 активны
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastPlayerIds?.length,
          equals(3),
          reason: 'Только 3 активных хранителя получают уведомление',
        );
        expect(
          env.edgeFn.lastPlayerIds,
          containsAll(['os1', 'os2', 'os3']),
        );
      },
    );

    test(
      'given OneSignal resolver бросает исключение '
      'when sendSOS '
      'then {success: false} без краша приложения',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'GUARDIAN1'},
          oneSignalIds: [],
          resolverError: Exception('Supabase unreachable'),
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse,
            reason: 'Ошибка Supabase при получении OneSignal IDs → {success: false}');
        expect(result.containsKey('error'), isTrue);
      },
    );
  });

  // ==========================================================================
  // Edge Function | Вызов и результат
  // ==========================================================================
  group('Edge Function | Вызов и возвращаемый результат', () {
    test(
      'given Edge Function возвращает {success: true} '
      'when sendSOS '
      'then sendSOS возвращает {success: true, recipients: N}',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1', 2: 'G2'},
          oneSignalIds: ['os1', 'os2'],
          edgeFnResponse: {'success': true},
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isTrue);
        expect(
          result['recipients'],
          equals(2),
          reason: 'recipients = количество OneSignal IDs, которым отправлено',
        );
      },
    );

    test(
      'given Edge Function возвращает {success: false, error: "CF error"} '
      'when sendSOS '
      'then sendSOS возвращает {success: false, error: "CF error"}',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
          edgeFnResponse: {'success': false, 'error': 'CF error'},
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(result['error'], equals('CF error'));
      },
    );

    test(
      'given Edge Function бросает исключение '
      'when sendSOS '
      'then sendSOS возвращает {success: false} без краша',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
          edgeFnError: Exception('Function timeout'),
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(result.containsKey('error'), isTrue,
            reason: 'Исключение Edge Function перехватывается и возвращается как error');
      },
    );

    test(
      'given Edge Function возвращает {success: false} без поля error '
      'when sendSOS '
      'then sendSOS возвращает {success: false, error: "Unknown error"}',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
          edgeFnResponse: {'success': false}, // нет поля error
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(
          result['error'],
          isNotEmpty,
          reason: 'Fallback при отсутствии error в ответе Edge Function',
        );
      },
    );

    test(
      'given sendSOS выполняется успешно с 1 хранителем '
      'when проверяем количество вызовов Edge Function '
      'then Edge Function вызвана ровно 1 раз',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
        );

        await SosService.sendSOS();

        expect(env.edgeFn.callCount, equals(1),
            reason: 'Edge Function вызывается ровно один раз за sendSOS');
      },
    );
  });

  // ==========================================================================
  // Данные, передаваемые в Edge Function (message + player_ids)
  // ==========================================================================
  group('Edge Function | Корректность передаваемых данных', () {
    test(
      'given имя "Alice", ID "XY123456", 2 хранителя '
      'when sendSOS '
      'then Edge Function получает правильное message И правильные player_ids',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1', 2: 'G2'},
          oneSignalIds: ['os_g1', 'os_g2'],
        );

        await SosService.sendSOS();

        // Message
        expect(
          env.edgeFn.lastMessage,
          equals('SOS Emergency from Alice (XY123456)'),
        );

        // Player IDs
        expect(
          env.edgeFn.lastPlayerIds,
          containsAll(['os_g1', 'os_g2']),
        );
        expect(env.edgeFn.lastPlayerIds?.length, equals(2));
      },
    );

    test(
      'given нет имени, ID "XY123456" '
      'when sendSOS '
      'then Edge Function получает message без скобок и имени',
      () async {
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: null,
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os_g1'],
        );

        await SosService.sendSOS();

        // Нет имени → нет скобок
        expect(env.edgeFn.lastMessage, equals('SOS Emergency from XY123456'));
        expect(env.edgeFn.lastMessage, isNot(contains('(')));
        expect(env.edgeFn.lastMessage, isNot(contains(')')));
      },
    );

    test(
      'given 5 хранителей, все активны '
      'when sendSOS '
      'then все 5 OneSignal IDs переданы в Edge Function',
      () async {
        final fiveIds = ['os1', 'os2', 'os3', 'os4', 'os5'];
        final env = await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1', 2: 'G2', 3: 'G3', 4: 'G4', 5: 'G5'},
          oneSignalIds: fiveIds,
        );

        await SosService.sendSOS();

        expect(
          env.edgeFn.lastPlayerIds,
          containsAll(fiveIds),
        );
        expect(env.edgeFn.lastPlayerIds?.length, equals(5));
      },
    );
  });

  // ==========================================================================
  // sendSOS — итоговые возвращаемые значения (структура ответа)
  // ==========================================================================
  group('sendSOS | Структура возвращаемого результата', () {
    test(
      'given успешная отправка '
      'when sendSOS '
      'then результат содержит поля success=true и recipients=число',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
          edgeFnResponse: {'success': true},
        );

        final result = await SosService.sendSOS();

        expect(result.containsKey('success'), isTrue);
        expect(result.containsKey('recipients'), isTrue);
        expect(result['success'], isTrue);
        expect(result['recipients'], isA<int>());
      },
    );

    test(
      'given нет хранителей '
      'when sendSOS '
      'then результат содержит success=false и error (строку)',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {},
          oneSignalIds: [],
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isFalse);
        expect(result['error'], isA<String>());
        expect((result['error'] as String).isNotEmpty, isTrue);
      },
    );

    test(
      'given любая ошибка в процессе '
      'when sendSOS '
      'then метод не выбрасывает исключение (всегда возвращает Map)',
      () async {
        await setUpSosTest(
          userId: 'XY123456',
          userName: 'Alice',
          guardianIds: {1: 'G1'},
          oneSignalIds: ['os1'],
          edgeFnError: Exception('Fatal error'),
        );

        // sendSOS должен вернуть Map, а не выбросить исключение
        expect(
          () async => await SosService.sendSOS(),
          returnsNormally,
          reason: 'sendSOS всегда возвращает Map — никогда не пробрасывает исключения',
        );
      },
    );
  });

  // ==========================================================================
  // Регрессия | Существующее поведение не сломано
  // ==========================================================================
  group('Регрессия | Существующий функционал SOS', () {
    test(
      'given стандартный сценарий (имя есть, хранители есть, Edge Function OK) '
      'when sendSOS '
      'then возвращает {success: true}',
      () async {
        await setUpSosTest(
          userId: 'MYID1234',
          userName: 'Bob',
          guardianIds: {1: 'GUARD001', 2: 'GUARD002'},
          oneSignalIds: ['os_guard1', 'os_guard2'],
          edgeFnResponse: {'success': true},
        );

        final result = await SosService.sendSOS();

        expect(result['success'], isTrue);
        expect(result['recipients'], equals(2));
      },
    );

    test(
      'given новые поля (message с именем) не ломают recipients в ответе '
      'when sendSOS выполняется успешно '
      'then recipients = количество OneSignal IDs (не количество guardianIds)',
      () async {
        // 5 guardianIds, но только 3 из них активны (имеют OneSignal ID)
        final env = await setUpSosTest(
          userId: 'MYID1234',
          userName: 'Bob',
          guardianIds: {1: 'G1', 2: 'G2', 3: 'G3', 4: 'G4', 5: 'G5'},
          oneSignalIds: ['os1', 'os2', 'os3'], // 3 активных
          edgeFnResponse: {'success': true},
        );

        final result = await SosService.sendSOS();

        expect(result['recipients'], equals(3),
            reason:
                'recipients отражает количество реально уведомлённых '
                '(OneSignal IDs), а не количество сохранённых хранителей');
      },
    );
  });
}
