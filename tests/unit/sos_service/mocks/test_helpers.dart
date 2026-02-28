// ============================================================
// Тестовые хелперы для SOSService тестов
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:emergency_app/services/sos_service.dart';

// ---------------------------------------------------------------------------
// MockEdgeFunction
// ---------------------------------------------------------------------------
// Перехватывает вызов Edge Function 'send-sos'.
// Фиксирует переданные message и player_ids для проверки в тестах.
// ---------------------------------------------------------------------------
class MockEdgeFunction {
  /// Список всех вызовов: [{playerIds: [...], message: '...'}]
  final List<Map<String, Object>> calls = [];

  /// Ответ, который будет возвращён
  Map<String, dynamic> responseToReturn = {'success': true};

  /// Ошибка для выброса (null = не бросать)
  Object? errorToThrow;

  /// Задержка перед ответом
  Duration? delay;

  Future<Map<String, dynamic>> call(
    List<String> playerIds,
    String message,
  ) async {
    calls.add({'playerIds': playerIds, 'message': message});
    if (delay != null) await Future.delayed(delay!);
    if (errorToThrow != null) throw errorToThrow!;
    return Map<String, dynamic>.from(responseToReturn);
  }

  /// Сообщение из последнего вызова
  String? get lastMessage =>
      calls.isNotEmpty ? calls.last['message'] as String? : null;

  /// player_ids из последнего вызова
  List<String>? get lastPlayerIds =>
      calls.isNotEmpty ? calls.last['playerIds'] as List<String>? : null;

  /// Количество вызовов
  int get callCount => calls.length;

  void reset() {
    calls.clear();
    responseToReturn = {'success': true};
    errorToThrow = null;
    delay = null;
  }
}

// ---------------------------------------------------------------------------
// MockOneSignalResolver
// ---------------------------------------------------------------------------
// Перехватывает SupabaseService.getGuardianOneSignalIds().
// Позволяет контролировать, какие OneSignal IDs "найдены" в Supabase.
// ---------------------------------------------------------------------------
class MockOneSignalResolver {
  final List<List<String>> callsArgs = [];
  List<String> responseToReturn = [];
  Object? errorToThrow;

  Future<List<String>> call(List<String> guardianUserIds) async {
    callsArgs.add(List.from(guardianUserIds));
    if (errorToThrow != null) throw errorToThrow!;
    return List.from(responseToReturn);
  }

  List<String>? get lastArgs =>
      callsArgs.isNotEmpty ? callsArgs.last : null;

  void reset() {
    callsArgs.clear();
    responseToReturn = [];
    errorToThrow = null;
  }
}

// ---------------------------------------------------------------------------
// Вспомогательная: единая настройка окружения для теста SosService
// ---------------------------------------------------------------------------
Future<({MockEdgeFunction edgeFn, MockOneSignalResolver resolver})> setUpSosTest({
  required String userId,
  String? userName,                            // null = имя не установлено
  Map<int, String> guardianIds = const {},     // слот → guardianUserId
  List<String> oneSignalIds = const ['os_id_1'], // возвращает resolver
  Map<String, dynamic> edgeFnResponse = const {'success': true},
  Object? edgeFnError,
  Object? resolverError,
}) async {
  // SharedPreferences
  final Map<String, Object> prefs = {'myUserId': userId};
  if (userName != null && userName.isNotEmpty) {
    prefs['user_name'] = userName;
  } else if (userName == '') {
    // явно пустая строка — записываем, чтобы тест мог проверить
    prefs['user_name'] = '';
  }
  for (final entry in guardianIds.entries) {
    prefs['guardian${entry.key}'] = entry.value;
  }
  SharedPreferences.setMockInitialValues(prefs);

  // Мок Edge Function
  final edgeFn = MockEdgeFunction()
    ..responseToReturn = Map<String, dynamic>.from(edgeFnResponse)
    ..errorToThrow = edgeFnError;
  SosService.setEdgeFunctionOverride(edgeFn.call);

  // Мок OneSignal resolver
  final resolver = MockOneSignalResolver()
    ..responseToReturn = List.from(oneSignalIds)
    ..errorToThrow = resolverError;
  SosService.setGetOneSignalIdsOverride(resolver.call);

  return (edgeFn: edgeFn, resolver: resolver);
}

// ---------------------------------------------------------------------------
// Teardown
// ---------------------------------------------------------------------------
void tearDownSosTest() {
  SosService.setEdgeFunctionOverride(null);
  SosService.setGetOneSignalIdsOverride(null);
}
