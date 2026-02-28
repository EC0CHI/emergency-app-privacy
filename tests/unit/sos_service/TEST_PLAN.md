# Test Plan — SOSService: формат SOS-сообщения (Модуль 5)

## Overview

- **Модуль:** `lib/services/sos_service.dart`
- **Цель:** Проверить корректное формирование SOS-сообщения с именем пользователя (FR-20), передачу данных в Edge Function и обратную совместимость существующего функционала
- **Ожидаемый статус:** 🔴 **ALL TESTS ARE RED** — SosService ещё не читает `userName`, формат сообщения устарел

---

## ⚠️ Замечание по нумерации FR

Пользователь указал **FR-25, FR-26, FR-27** — таких требований в SPEC_VALIDATED.md v1.1 нет.
Спецификация заканчивается на **FR-20**. Тесты написаны по фактическому требованию:

| Указано (ошибочно) | Фактическое | Описание |
|--------------------|-------------|----------|
| FR-25 | **FR-20** | Формат сообщения SOS с именем/без имени |
| FR-26 | не существует | — |
| FR-27 | не существует | — |

---

## Текущее состояние vs Требуемое

```dart
// ТЕКУЩИЙ КОД (до реализации — НЕВЕРНО):
'message': 'Emergency alert from $myUserId'

// ТРЕБУЕТСЯ (FR-20):
// Если имя установлено:
'message': 'SOS Emergency from $userName ($myUserId)'
// Если имени нет:
'message': 'SOS Emergency from $myUserId'
```

---

## Команды запуска

```bash
# Все тесты модуля 5
flutter test tests/unit/sos_service/ --reporter expanded

# Только тесты формата сообщения (FR-20)
flutter test tests/unit/sos_service/ --name "FR-20"
flutter test tests/unit/sos_service/ --name "AC-14"
flutter test tests/unit/sos_service/ --name "AC-15"

# Регрессионные тесты
flutter test tests/unit/sos_service/ --name "Регрессия"
```

## Структура файлов

```
tests/unit/sos_service/
  mocks/
    test_helpers.dart          # MockEdgeFunction, MockOneSignalResolver, setUpSosTest
  sos_service_test.dart        # 28 unit-тестов
  TEST_PLAN.md                 # Этот документ
```

---

## Архитектурный контракт для реализации

### Два override для тестируемости

```dart
class SosService {
  // Override 1: заменяет вызов Edge Function
  static Future<Map<String, dynamic>> Function(List<String> playerIds, String message)?
      _edgeFunctionOverride;

  @visibleForTesting
  static void setEdgeFunctionOverride(
    Future<Map<String, dynamic>> Function(List<String>, String)? fn,
  ) => _edgeFunctionOverride = fn;

  // Override 2: заменяет SupabaseService.getGuardianOneSignalIds()
  static Future<List<String>> Function(List<String> guardianUserIds)?
      _getOneSignalIdsOverride;

  @visibleForTesting
  static void setGetOneSignalIdsOverride(
    Future<List<String>> Function(List<String>)? fn,
  ) => _getOneSignalIdsOverride = fn;
}
```

### Обновлённый `sendSOS()`

```dart
static Future<Map<String, dynamic>> sendSOS() async {
  try {
    final myUserId = await UserService.getUserId();
    final userName = await UserService.getUserName(); // НОВЫЙ вызов — FR-20

    final guardianUserIds = await _getGuardianUserIds();
    if (guardianUserIds.isEmpty) {
      return {'success': false, 'error': 'No guardians configured'};
    }

    final oneSignalIds = _getOneSignalIdsOverride != null
        ? await _getOneSignalIdsOverride!(guardianUserIds)
        : await SupabaseService.getGuardianOneSignalIds(guardianUserIds);

    if (oneSignalIds.isEmpty) {
      return {
        'success': false,
        'error': 'No active guardians found. Make sure they have the app installed.',
      };
    }

    // FR-20: формирование сообщения с именем
    final message = (userName != null && userName.isNotEmpty)
        ? 'SOS Emergency from $userName ($myUserId)'
        : 'SOS Emergency from $myUserId';

    final result = _edgeFunctionOverride != null
        ? await _edgeFunctionOverride!(oneSignalIds, message)
        : await _callEdgeFunction(oneSignalIds, message);

    if (result['success'] == true) {
      return {'success': true, 'recipients': oneSignalIds.length};
    } else {
      return {'success': false, 'error': result['error'] ?? 'Unknown error'};
    }
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// Выделить вызов Edge Function в отдельный метод для тестируемости
static Future<Map<String, dynamic>> _callEdgeFunction(
  List<String> playerIds,
  String message,
) async {
  final response = await Supabase.instance.client.functions.invoke(
    'send-sos',
    body: {'player_ids': playerIds, 'message': message},
  );
  return response.data as Map<String, dynamic>;
}
```

---

## Матрица покрытия требований

### Группа 1: FR-20 | Формат сообщения

| Требование | Тест | Приоритет |
|------------|------|-----------|
| AC-14 | `given "Alice" + "XY123456" then "SOS Emergency from Alice (XY123456)"` | Critical |
| AC-15 | `given no name + "XY123456" then "SOS Emergency from XY123456"` | Critical |
| FR-20 | `given user_name = "" then ID-only message` | High |
| FR-20 | `given "Алиса" (Unicode) then message with "Алиса"` | High |
| FR-20 | `given "A" (1 char) then message with "A"` | Medium |
| FR-20 | `given 50 chars then full name in message` | Medium |
| FR-20 | `given "O'Brien" (special) then correct message` | Medium |
| FR-20 | `given different userId then message uses correct userId` | High |
| Регрессия | `given any case then message starts with "SOS Emergency from"` | Critical |

### Группа 2: Guardian IDs

| Требование | Тест | Приоритет |
|------------|------|-----------|
| Существующий | `given no guardians then {success: false}` | Critical |
| Существующий | `given all slots empty ("") then {success: false}` | High |
| Существующий | `given only guardian2 then only "BBBB2222" to resolver` | High |
| Существующий | `given guardian1 + guardian3 then both IDs to resolver` | Medium |
| Существующий | `given all 5 guardians then all 5 to resolver` | Medium |

### Группа 3: OneSignal IDs

| Требование | Тест | Приоритет |
|------------|------|-----------|
| Существующий | `given no OneSignal IDs then {success: false, "No active guardians"}` | Critical |
| Существующий | `given 3 of 5 active then 3 player_ids to Edge Function` | High |
| Существующий | `given resolver throws then {success: false}` | High |

### Группа 4: Edge Function

| Требование | Тест | Приоритет |
|------------|------|-----------|
| Существующий | `given {success: true} then {success: true, recipients: N}` | Critical |
| Существующий | `given {success: false, error: "X"} then {success: false, error: "X"}` | High |
| Существующий | `given throws then {success: false}` | High |
| Существующий | `given {success: false} no error field then fallback error` | Medium |
| Существующий | `given success then Edge Function called exactly once` | Medium |

### Группа 5: Передаваемые данные

| Требование | Тест | Приоритет |
|------------|------|-----------|
| FR-20 + Существующий | `given "Alice" + 2 guardians then correct message + player_ids` | Critical |
| AC-15 | `given no name then message without parentheses` | High |
| Существующий | `given 5 active then all 5 player_ids sent` | Medium |

### Группа 6: Структура результата

| Требование | Тест | Приоритет |
|------------|------|-----------|
| Существующий | `given success then has success=true, recipients=int` | Critical |
| Существующий | `given no guardians then has success=false, error=string` | High |
| Существующий | `given any error then sendSOS never throws` | Critical |

### Группа 7: Регрессия

| Требование | Тест | Приоритет |
|------------|------|-----------|
| Регрессия | `given standard scenario then {success: true}` | Critical |
| Регрессия | `given 5 guardians, 3 active then recipients = 3` | High |

---

## Зоны риска

1. **Устаревший формат сообщения (критический):** Текущая строка `'Emergency alert from $myUserId'` должна быть заменена. Тест `given any case then message starts with "SOS Emergency from"` является регрессионным детектором этой ошибки.

2. **Новый вызов `UserService.getUserName()`:** SosService должен вызывать этот метод — он будет добавлен при реализации UserService. Если метод отсутствует — тесты не скомпилируются (RED).

3. **Пустая строка в `user_name`:** Если `user_name = ""` сохранена в SharedPreferences, SosService должен трактовать её как "нет имени" и не включать в сообщение. Тест `given user_name = "" then ID-only message` проверяет этот граничный случай.

4. **`recipients` = OneSignal IDs, не guardianIds:** `recipients` должен отражать количество реально уведомлённых (число OneSignal IDs), а не количество сохранённых ID хранителей.

5. **sendSOS никогда не бросает исключение:** Все ошибки должны быть пойманы и возвращены в `{success: false, error: ...}`. Клиент (MainScreen) рассчитывает на это.

---

## Итог

| Файл | Групп | Тест-кейсов |
|------|-------|-------------|
| `sos_service_test.dart` | 7 | **28** |
| **Итого** | **7** | **28** |

**Покрытые требования:** FR-20, AC-14, AC-15 + регрессионное покрытие существующего функционала sendSOS
