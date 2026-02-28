// ============================================================
// MockGuardiansService — управляемый мок для GuardiansService
// ============================================================
// Используется в widget-тестах GuardiansScreen и GuardianListWidget.
// Поддерживает:
//   1. Простые ответы (userId → String?)
//   2. Completer-based ответы (для тестов race condition / порядка)
//   3. Симуляцию ошибок
//   4. Счётчик вызовов
// ============================================================

import 'dart:async';

class MockGuardiansService {
  // ---------------------------------------------------------------------------
  // Состояние
  // ---------------------------------------------------------------------------

  /// Предопределённые ответы: userId → имя (или null)
  final Map<String, String?> _responses = {};

  /// Completer-based ответы: userId → Completer (для контроля порядка)
  final Map<String, Completer<String?>> _completers = {};

  /// Последовательные ответы для одного userId (для race condition тестов).
  /// Каждый вызов берёт следующий Completer из списка.
  final Map<String, List<Completer<String?>>> _sequentialCompleters = {};
  final Map<String, int> _callIndexPerUserId = {};

  /// Лог вызовов (userId в порядке вызовов)
  final List<String> calls = [];

  /// Ошибка для выброса (null = не бросать)
  Object? errorToThrow;

  /// Задержка ответа (null = мгновенно)
  Duration? responseDelay;

  // ---------------------------------------------------------------------------
  // Настройка
  // ---------------------------------------------------------------------------

  /// Установить предопределённый ответ для userId
  void setResponse(String userId, String? name) {
    _responses[userId] = name;
  }

  /// Установить ответ по умолчанию для любого userId
  void setDefaultResponse(String? name) {
    _responses['*'] = name;
  }

  /// Создать Completer для userId — ответ будет ожидать вызова complete()
  /// Используется для контроля порядка завершения async-операций.
  Completer<String?> createCompleter(String userId) {
    final c = Completer<String?>();
    _completers[userId] = c;
    return c;
  }

  /// Создать список последовательных Completer'ов для userId.
  /// Каждый вызов findUserName с этим userId будет использовать следующий Completer.
  List<Completer<String?>> createSequentialCompleters(String userId, int count) {
    final completers = List.generate(count, (_) => Completer<String?>());
    _sequentialCompleters[userId] = completers;
    _callIndexPerUserId[userId] = 0;
    return completers;
  }

  // ---------------------------------------------------------------------------
  // Функция-мок — передаётся в GuardiansService.setFindUserNameOverride
  // ---------------------------------------------------------------------------
  Future<String?> findUserName(String userId) async {
    calls.add(userId);

    if (errorToThrow != null) throw errorToThrow!;

    if (responseDelay != null) {
      await Future.delayed(responseDelay!);
    }

    // Последовательные Completer'ы (для race condition)
    if (_sequentialCompleters.containsKey(userId)) {
      final index = _callIndexPerUserId[userId]!;
      _callIndexPerUserId[userId] = index + 1;
      final completers = _sequentialCompleters[userId]!;
      if (index < completers.length) {
        return completers[index].future;
      }
    }

    // Разовый Completer (для порядка загрузки)
    if (_completers.containsKey(userId)) {
      return _completers[userId]!.future;
    }

    // Предопределённый ответ
    if (_responses.containsKey(userId)) return _responses[userId];
    if (_responses.containsKey('*')) return _responses['*'];

    return null;
  }

  // ---------------------------------------------------------------------------
  // Сброс состояния
  // ---------------------------------------------------------------------------
  void reset() {
    _responses.clear();
    _completers.clear();
    _sequentialCompleters.clear();
    _callIndexPerUserId.clear();
    calls.clear();
    errorToThrow = null;
    responseDelay = null;
  }
}
