# Test Plan — UserService (Модуль 1)

## Overview

- **Модуль:** `lib/services/user_service.dart`
- **Цель:** Проверить корректность реализации трёх новых методов: `hasUserName()`, `getUserName()`, `saveUserName(String)`
- **Ожидаемый статус:** 🔴 **ALL TESTS ARE RED** — методы ещё не реализованы. Это корректное TDD-состояние.

## Зависимости для запуска

Добавить в `pubspec.yaml` → `dev_dependencies`:
```yaml
mocktail: ^0.3.0
```

Затем:
```bash
flutter pub get
```

## Команда запуска

```bash
# Все тесты модуля
flutter test tests/unit/user_service/user_service_test.dart

# С подробным выводом
flutter test tests/unit/user_service/user_service_test.dart --reporter expanded

# Только группа FR-01
flutter test tests/unit/user_service/user_service_test.dart --name "FR-01"
```

## Структура файлов

```
tests/unit/user_service/
  user_service_test.dart       # Основные unit-тесты (этот файл)
  mocks/
    mock_supabase_service.dart # MockSupabasePersistence — замена Supabase-слоя
  TEST_PLAN.md                 # Этот документ
```

## Требование к реализации: инжекция Supabase-зависимости

Для прохождения тестов `UserService` должен поддерживать переопределение
Supabase-вызова в тестовой среде. Рекомендуемый паттерн:

```dart
class UserService {
  static const String _userNameKey = 'user_name';

  // @visibleForTesting
  static Future<void> Function(String userId, String name)?
      _supabaseSaveOverride;

  @visibleForTesting
  static void setSupabaseSaveOverride(
    Future<void> Function(String userId, String name)? fn,
  ) {
    _supabaseSaveOverride = fn;
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('myUserId');
    if (userId == null || userId.isEmpty) {
      throw StateError('Cannot save user name: userId not initialized');
    }

    // NFR-06: SharedPreferences сохраняется ДО Supabase
    await prefs.setString(_userNameKey, name);

    // Supabase-вызов (реальный или мок)
    final saveFn = _supabaseSaveOverride ??
        (u, n) => SupabaseService.updateUserName(u, n);
    await saveFn(userId, name); // пробрасывает исключение вызывающему
  }
}
```

## Матрица покрытия требований

| Требование | Описание | Тест(ы) | Тип | Приоритет |
|------------|----------|---------|-----|-----------|
| FR-01 | `hasUserName()` → false при пустом prefs | `FR-01 \| 'given SharedPreferences is empty'` | Unit | Critical |
| FR-01 | `hasUserName()` → false при отсутствии ключа | `FR-01 \| 'given user_name key does not exist'` | Unit | Critical |
| FR-01 | `hasUserName()` → false при пустой строке | `FR-01 \| 'given user_name is stored as empty string'` | Unit | Critical |
| FR-01 | `hasUserName()` → true при непустом значении | `FR-01 \| 'given user_name is set to "Alice"'` | Unit | Critical |
| FR-01 | `hasUserName()` → true при 1 символе | `FR-01 \| 'given user_name is a single character'` | Unit | High |
| FR-01 | `hasUserName()` → true при 50 символах | `FR-01 \| 'given user_name is exactly 50 characters'` | Unit | High |
| FR-01 | `hasUserName()` → true для Unicode | `FR-01 \| 'given user_name contains unicode'` | Unit | Medium |
| FR-04 | Условие роутинга: нет имени → WelcomeScreen | `FR-04 \| 'given имя не установлено'` | Unit | Critical |
| FR-04 | Условие роутинга: имя есть → MainScreen | `FR-04 \| 'given имя установлено "Bob"'` | Unit | Critical |
| FR-02 | `getUserName()` → null при пустом prefs | `FR-02 \| 'given SharedPreferences is empty'` | Unit | Critical |
| FR-02 | `getUserName()` → null при отсутствии ключа | `FR-02 \| 'given user_name key is absent'` | Unit | Critical |
| FR-02 | `getUserName()` → null при пустой строке | `FR-02 \| 'given user_name is stored as empty string'` | Unit | Critical |
| FR-02 | `getUserName()` → точное значение "Alice" | `FR-02 \| 'given user_name is "Alice"'` | Unit | Critical |
| FR-02 | `getUserName()` → Unicode "Алиса" без изменений | `FR-02 \| 'given user_name contains unicode'` | Unit | High |
| FR-02 | `getUserName()` → спецсимволы без изменений | `FR-02 \| 'given user_name contains special characters'` | Unit | Medium |
| FR-02 | `getUserName()` → 50 символов без усечения | `FR-02 \| 'given user_name is exactly 50 characters'` | Unit | High |
| FR-02 | `getUserName()` → только user_name, не userId | `FR-02 \| 'given user_name and userId both in prefs'` | Unit | High |
| FR-03 | `saveUserName` сохраняет в SharedPreferences | `FR-03 \| 'given пустые SharedPreferences'` | Unit | Critical |
| FR-03 | `saveUserName` обновляет существующее имя | `FR-03 \| 'given сохранено имя "Alice"'` | Unit | Critical |
| FR-03 | После `saveUserName` → `hasUserName()` = true | `FR-03 \| 'after save hasUserName returns true'` | Unit | Critical |
| FR-03 | После `saveUserName` → `getUserName()` = name | `FR-03 \| 'after save getUserName returns name'` | Unit | Critical |
| FR-03 | `saveUserName` вызывает Supabase ровно 1 раз | `FR-03 \| 'Supabase update вызван ровно один раз'` | Unit | Critical |
| FR-03 | `saveUserName` передаёт корректные userId+name | `FR-03 \| 'Supabase update вызван с корректными'` | Unit | Critical |
| FR-03 | `saveUserName` дважды → Supabase вызван дважды | `FR-03 \| 'saveUserName("Bob") вызван после'` | Unit | High |
| FR-03 | 50 символов сохраняются без усечения | `FR-03 \| 'имя из 50 символов'` | Unit | High |
| FR-03 | Спецсимволы сохраняются (EC-09) | `FR-03 \| 'имя содержит специальные символы'` | Unit | Medium |
| FR-03 | Нет userId → выбрасывает исключение | `FR-03 \| 'given userId ещё не создан'` | Unit | Critical |
| NFR-06 | Supabase упал → SharedPreferences сохранён | `NFR-06 \| 'Supabase выбрасывает исключение'` × 3 | Unit | Critical |
| NFR-06 | Supabase упал → исключение пробрасывается | `NFR-06 \| 'исключение пробрасывается вызывающему'` | Unit | Critical |
| EC-03 | Сбой Supabase → данные доступны локально | Интеграционный тест в группе "Интеграция" | Unit | High |

## Зоны риска

1. **Порядок сохранения (NFR-06):** SharedPreferences ДОЛЖЕН сохраняться ДО вызова Supabase. Если порядок перепутан — при сетевой ошибке имя не будет доступно локально.

2. **Инжекция зависимости:** Если `saveUserName` не поддерживает переопределение Supabase-функции — тесты невозможно запустить без реального Supabase. Паттерн `setSupabaseSaveOverride` обязателен.

3. **Пустая строка vs null:** `hasUserName()` и `getUserName()` должны одинаково трактовать пустую строку и отсутствие ключа (оба случая = "имя не установлено").

4. **Отсутствие userId:** `saveUserName` не должна молча игнорировать отсутствие userId — это ошибка инициализации, должно выбрасываться исключение.

## Итог

| Тип | Файлов | Тест-кейсов |
|-----|--------|-------------|
| Unit (FR-01) | 1 | 9 |
| Unit (FR-02) | 1 | 7 |
| Unit (FR-03) | 1 | 12 |
| Unit (NFR-06) | 1 | 4 (в FR-03 + интеграция) |
| Интеграция | 1 | 3 |
| **Итого** | **1 файл** | **35 тест-кейсов** |
