# Test Plan — GuardiansService + GuardiansScreen + Guardian List Display (Модуль 3)

## Overview

- **Модуль:** `lib/services/guardians_service.dart` + `lib/screens/settings_screen.dart` (GuardiansScreen) + `lib/widgets/guardian_list_widget.dart`
- **Цель:** Проверить поиск пользователей по ID, ввод хранителей с debounce, сохранение nickname и отображение списка хранителей с именами
- **Ожидаемый статус:** 🔴 **ALL TESTS ARE RED** — GuardiansService, GuardiansScreen (рефакторинг), GuardianListWidget ещё не реализованы

## Зависимости для запуска

`pubspec.yaml` → `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  shared_preferences: ^2.2.0
```

```bash
flutter pub get
```

## Команды запуска

```bash
# Все тесты модуля 3
flutter test tests/unit/guardians/ --reporter expanded

# Только unit-тесты GuardiansService
flutter test tests/unit/guardians/guardians_service_test.dart

# Только widget-тесты GuardiansScreen (форма + debounce)
flutter test tests/unit/guardians/guardians_screen_test.dart

# Только тесты списка хранителей
flutter test tests/unit/guardians/guardian_list_display_test.dart

# По группе
flutter test tests/unit/guardians/ --name "FR-08"
flutter test tests/unit/guardians/ --name "FR-15"
flutter test tests/unit/guardians/ --name "EC-07"
flutter test tests/unit/guardians/ --name "EC-04"
```

## Структура файлов

```
tests/unit/guardians/
  mocks/
    mock_guardians_service.dart      # MockGuardiansService с поддержкой Completer
    test_helpers.dart                # Ключи, buildGuardiansTestApp, setup/teardown
  guardians_service_test.dart        # Unit-тесты GuardiansService.findUserName()
  guardians_screen_test.dart         # Widget-тесты GuardiansScreen (edit form)
  guardian_list_display_test.dart    # Widget-тесты GuardianListWidget
  TEST_PLAN.md                       # Этот документ
```

## Архитектурные контракты для реализации

### GuardiansService (`lib/services/guardians_service.dart`)

```dart
class GuardiansService {
  // Уровень 1: подмена Supabase-запроса (для unit-тестов логики)
  static Future<Map<String, dynamic>?> Function(String userId)?
      _supabaseQueryOverride;

  @visibleForTesting
  static void setSupabaseQueryOverride(
    Future<Map<String, dynamic>?> Function(String)? fn,
  ) => _supabaseQueryOverride = fn;

  // Уровень 2: подмена всего findUserName (для widget-тестов)
  static Future<String?> Function(String userId)? _findUserNameOverride;

  @visibleForTesting
  static void setFindUserNameOverride(
    Future<String?> Function(String)? fn,
  ) => _findUserNameOverride = fn;

  static Future<String?> findUserName(String userId) async {
    if (_findUserNameOverride != null) return _findUserNameOverride!(userId);
    try {
      final result = (_supabaseQueryOverride != null)
          ? await _supabaseQueryOverride!(userId)
                .timeout(const Duration(seconds: 5))
          : await Supabase.instance.client
                .from('users')
                .select('user_name')
                .eq('user_id', userId)
                .maybeSingle()
                .timeout(const Duration(seconds: 5));
      if (result == null) return null;
      final name = result['user_name'] as String?;
      return (name == null || name.isEmpty) ? null : name;
    } catch (_) {
      return null;
    }
  }
}
```

### GuardiansScreen (`lib/screens/settings_screen.dart`)

Рефакторинг `EmergencyNumberScreen`:
- Добавить поля Nickname (Key: `Key('guardian_nickname_field_$slot')`)
- Добавить debounce 500ms через `Timer` с `_generationCounter` для race condition protection
- Добавить статус поиска (Key: `Key('guardian_search_status_$slot')`)
- Добавить loading per slot (Key: `Key('guardian_search_loading_$slot')`)
- Кнопка Save: Key('guardians_save_button')
- При сохранении: `guardian$i` + `guardian${i}_nickname` в SharedPreferences

**Race condition protection (EC-04):**
```dart
int _generation = 0;

void _onGuardianChanged(int slot, String value) {
  _debounceTimers[slot]?.cancel();
  if (value.isEmpty) {
    setState(() { _searchStates[slot] = _SearchState.idle; });
    return;
  }
  _debounceTimers[slot] = Timer(const Duration(milliseconds: 500), () async {
    final gen = ++_generation;
    setState(() { _searchStates[slot] = _SearchState.loading; });
    final name = await GuardiansService.findUserName(value);
    if (gen != _generation) return; // устаревший ответ
    setState(() { _searchStates[slot] = name != null
        ? _SearchState.found(name)
        : _SearchState.notFound; });
  });
}
```

### GuardianListWidget (`lib/widgets/guardian_list_widget.dart`)

```dart
class GuardianListWidget extends StatefulWidget {
  const GuardianListWidget({super.key});
  // Читает guardian1..5 из SharedPreferences
  // Параллельно запрашивает имена через GuardiansService
  // Отображает в порядке guardian1..5 (не Future.wait completion order)
  // Ключи: Key('guardian_list_item_$slot'),
  //        Key('guardian_list_primary_$slot'),
  //        Key('guardian_list_secondary_$slot'),
  //        Key('guardian_list_loading_$slot')
}
```

Порядок отображения (EC-07):
```dart
// ПРАВИЛЬНО: Future.wait с индексированным списком
final results = await Future.wait(
  guardianIds.asMap().entries
    .where((e) => e.value.isNotEmpty)
    .map((e) => GuardiansService.findUserName(e.value)),
);
// results[i] соответствует guardianIds[i] — порядок сохранён
```

## Матрица покрытия требований

### guardians_service_test.dart

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-08 | findUserName возвращает имя | `given user_name = "Charlie" then returns "Charlie"` | Critical |
| FR-08 | findUserName: Unicode имя | `given user_name = "Алиса" then returns "Алиса"` | High |
| FR-08 | findUserName: спецсимволы | `given user_name = "O'Brien"` | Medium |
| FR-08 | findUserName: user not found → null | `given Supabase null then returns null` | Critical |
| FR-08 | EC-12: legacy user (null) → null | `given user_name = null (legacy)` | High |
| FR-08 | empty string → null | `given user_name = "" then null` | High |
| FR-08 | userId передаётся корректно | `given "ABCD1234" then query uses "ABCD1234"` | Critical |
| EC-05 | Неполный ID → выполняет запрос | `given userId = "ABC" then executes, returns null` | Medium |
| EC-06 | Собственный ID → own name | `given own userId then returns own name` | Low |
| EC-08 | Exception → null, no crash | `given throws Exception then returns null` | Critical |
| EC-08 | StateError (no column) → null | `given StateError then returns null` | High |
| EC-08 | RLS denied → null | `given permission denied then returns null` | High |
| EC-08 | Ошибки изолированы между вызовами | `given error on first, ok on second then results isolated` | Medium |
| NFR-02 | Timeout > 5s → null | `given 6s response then returns null after timeout` | Critical |
| NFR-02 | Timeout < 5s → результат | `given 4s response then returns name` | High |

### guardians_screen_test.dart

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-09 | 5 ID полей присутствуют | `given render then 5 id fields` | Critical |
| FR-12 | 5 nickname полей присутствуют | `given render then 5 nickname fields (FR-12)` | Critical |
| FR-09 | Предзаполнение ID из prefs | `given guardian1="ABCD1234" then field pre-populated` | Critical |
| FR-12 | Предзаполнение nickname из prefs | `given guardian1_nickname="Mom" then field pre-populated` | High |
| FR-09 | Пустые поля при пустых prefs | `given empty prefs then all fields empty` | Medium |
| AC-07 / FR-10 | Debounce 500ms → Found | `given "ABCD1234" + 500ms then "✓ Found: Charlie"` | Critical |
| AC-08 / FR-11 | Debounce → Not found | `given "ZZZZZZZZ" + 500ms then "⚠️ User not found"` | Critical |
| FR-09 | До 500ms — нет результата | `given < 500ms then no result shown` | High |
| FR-09 | Loading indicator во время запроса | `given debounce fired, query pending then loading visible` | Medium |
| AC-17 | Очистка поля → сброс + нет запроса | `given field cleared then state reset, no query` | Critical |
| FR-09 | Только один запрос (последний) | `given fast typing then only one query at 500ms pause` | High |
| EC-04 | Race condition: stale response ignored | `given overlapping queries then last result shown` | High |
| FR-11 | Ошибка service → "⚠️ User not found" | `given service throws then "⚠️ User not found"` | High |
| AC-09 / FR-13 | ID + Nickname → SharedPreferences | `given ID+Nick then prefs guardian1/guardian1_nickname` | Critical |
| AC-10 / FR-13 | ID без Nickname → nickname="" | `given ID only then nickname="" in prefs` | Critical |
| FR-13 | Все 5 хранителей сохранены | `given 5 guardians then all saved` | High |
| FR-13 | Очищенное поле → "" в prefs | `given cleared field then guardian1="" in prefs` | Medium |
| EC-09 | Nickname с "O'Brien" | `given "O'Brien" nickname then saved correctly` | Medium |
| EC-09 | Nickname с кириллицей "Мама" | `given "Мама" nickname then saved correctly` | Medium |
| FR-09 | Независимость полей | `given search in field 1 then field 2 unaffected` | Medium |
| FR-09 | 2 поля с разными ID | `given field1 + field2 then each shows own result` | Medium |

### guardian_list_display_test.dart

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-14 | findUserName вызывается для каждого | `given 3 guardians then 3 findUserName calls` | Critical |
| NFR-07 | Параллельные запросы (Future.wait) | `given 3 guardians then all 3 start before any completes` | Critical |
| FR-14 | Пустые слоты — без запроса | `given 2 of 5 filled then only 2 queries` | High |
| FR-14 | Нет хранителей — 0 запросов | `given empty prefs then 0 queries` | Medium |
| AC-11 / FR-15 | Имя + Nickname → "Имя (Nickname)" | `given Charlie + Mom then "Charlie (Mom)"` | Critical |
| AC-12 / FR-15 | Имя, нет Nickname → "Имя" | `given Charlie, no nick then "Charlie"` | Critical |
| FR-15 | Нет имени + Nickname → "Nickname" | `given null name + Mom then "Mom"` | High |
| FR-15 | Нет имени, нет Nickname → User ID | `given null name, no nick then "ABCD1234"` | High |
| AC-13 / FR-16 | Ошибка + Nickname → только ID | `given error + Mom then "ABCD1234" only, no "Mom"` | Critical |
| FR-16 | Ошибка, нет Nickname → User ID | `given error, no nick then "ABCD1234"` | High |
| FR-16 | Ошибка для всех → все как User ID | `given error all then all shown as ID` | High |
| NFR-04 | Ошибка не крашит | `given critical error then app not crashed` | Critical |
| EC-07 | Порядок: guardian2 быстрее → guardian1 первый | `given guardian2 faster then guardian1 still first` | Critical |
| EC-07 | Обратный порядок ответов → порядок 1..5 | `given reverse completion then display 1..5 order` | High |
| Loading | Loading indicator во время запроса | `given pending query then loading visible` | Medium |
| Loading | Нет loading после завершения | `given queries done then no loading` | Medium |

## Зоны риска

1. **Race condition (EC-04):** Критический баг без generation counter. Тест `EC-04` документирует ожидаемое поведение. Реализация ОБЯЗАНА использовать счётчик поколений или cancellation token.

2. **Порядок Future.wait (EC-07):** `Future.wait` не гарантирует порядок завершения, но гарантирует порядок результатов в списке. Реализация ДОЛЖНА использовать `Future.wait(list)` и сопоставлять результаты по индексу, не по порядку завершения.

3. **FR-16 vs FR-15 (C-04):** При ошибке Supabase Nickname НЕ используется как fallback. Это намеренное ограничение (C-04: кэширование имён не реализовано). Тест `AC-13` явно проверяет этот инвариант.

4. **Debounce + dispose (memory leak):** При dispose GuardiansScreen активные Timer'ы должны быть отменены. Тест косвенно проверяет это через `tearDown`.

5. **Локализация в тестах:** `buildGuardiansTestApp` включает `AppLocalizations.localizationsDelegates`. Если `flutter gen-l10n` не запускался — тесты не скомпилируются. Нужно выполнить `flutter gen-l10n` перед запуском.

## Предусловия для запуска

1. `flutter gen-l10n` — генерация `app_localizations.dart`
2. Создать файлы реализации:
   - `lib/services/guardians_service.dart` (с `setSupabaseQueryOverride` + `setFindUserNameOverride`)
   - `lib/widgets/guardian_list_widget.dart` (GuardianListWidget)
   - Рефакторинг `lib/screens/settings_screen.dart` (GuardiansScreen класс вместо EmergencyNumberScreen)

## Итог

| Файл | Групп | Тест-кейсов |
|------|-------|-------------|
| `guardians_service_test.dart` | 4 | 15 |
| `guardians_screen_test.dart` | 6 | 22 |
| `guardian_list_display_test.dart` | 5 | 16 |
| **Итого** | **15** | **53** |

**Покрытые требования:** FR-08, FR-09, FR-10, FR-11, FR-12, FR-13, FR-14, FR-15, FR-16, AC-07, AC-08, AC-09, AC-10, AC-13, AC-17, EC-04, EC-05, EC-06, EC-07, EC-08, EC-09, EC-12, NFR-02, NFR-04, NFR-07
