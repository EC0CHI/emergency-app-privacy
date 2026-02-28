# Test Plan — WelcomeScreen + App Routing (Модуль 2)

## Overview

- **Модуль:** `lib/screens/welcome_screen.dart` + роутинг в `lib/main.dart`
- **Цель:** Проверить UI WelcomeScreen (поле ввода, кнопка, валидация, навигация) и логику роутинга MyApp (hasUserName → WelcomeScreen | MainScreen)
- **Ожидаемый статус:** 🔴 **ALL TESTS ARE RED** — WelcomeScreen и роутинг ещё не реализованы. Это корректное TDD-состояние.

## Зависимости для запуска

`pubspec.yaml` → `dev_dependencies` должен содержать:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  shared_preferences: ^2.2.0   # уже в dependencies, нужен для mock
```

Запуск:
```bash
flutter pub get
```

## Команды запуска

```bash
# Все тесты модуля 2
flutter test tests/unit/welcome_screen/

# Только тесты WelcomeScreen (UI)
flutter test tests/unit/welcome_screen/welcome_screen_widget_test.dart

# Только тесты роутинга
flutter test tests/unit/welcome_screen/app_routing_test.dart

# С подробным выводом
flutter test tests/unit/welcome_screen/ --reporter expanded

# Конкретная группа
flutter test tests/unit/welcome_screen/ --name "FR-05"
flutter test tests/unit/welcome_screen/ --name "FR-07"
flutter test tests/unit/welcome_screen/ --name "EC-11"
```

## Структура файлов

```
tests/unit/welcome_screen/
  welcome_screen_widget_test.dart  # Widget-тесты WelcomeScreen в изоляции
  app_routing_test.dart            # Widget-тесты роутинга MyApp
  mocks/
    test_helpers.dart              # Общие хелперы, ключи, TestNavigatorObserver
  TEST_PLAN.md                     # Этот документ
```

## Архитектурные требования к реализации

### WelcomeScreen

```dart
// Обязательные ключи виджетов:
// Key('welcome_name_field')       — TextField для ввода имени
// Key('welcome_continue_button')  — ElevatedButton "Continue"
// Key('welcome_loading_indicator')— CircularProgressIndicator во время сохранения

class WelcomeScreen extends StatefulWidget {
  // Не принимает параметры (читает userId из SharedPreferences)
}
```

Ключевые UX-требования:
- Кнопка Continue `disabled` (onPressed == null) когда поле пустое или состоит только из пробелов
- Кнопка Continue `enabled` когда `trim().isNotEmpty`
- При нажатии Continue: показать loading indicator, вызвать `UserService.saveUserName(name.trim())`
- После успешного сохранения: `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainScreen(...)))`
- При ошибке Supabase: показать SnackBar с сообщением об ошибке (экран остаётся)
- Back navigation заблокирована (`PopScope(canPop: false)` или `WillPopScope`)

### Роутинг в MyApp

```dart
class MyApp extends StatefulWidget {
  // КРИТИЧЕСКИ важно: не вызывать Supabase/OneSignal в initState/build
  // Роутинг зависит ТОЛЬКО от SharedPreferences
}

class _MyAppState extends State<MyApp> {
  bool? _hasUserName; // null = loading, false = WelcomeScreen, true = MainScreen

  @override
  void initState() {
    super.initState();
    _checkUserName();
  }

  Future<void> _checkUserName() async {
    final result = await UserService.hasUserName();
    setState(() => _hasUserName = result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: switch (_hasUserName) {
        null  => const Scaffold(body: Center(child: CircularProgressIndicator())),
        false => const WelcomeScreen(),
        true  => MainScreen(updateLocale: _updateLocale),
      },
    );
  }
}
```

## Матрица покрытия требований

### welcome_screen_widget_test.dart

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-05 | WelcomeScreen содержит поле ввода имени | `[AC-01] given WelcomeScreen показан → TextField с ключом kWelcomeNameField` | Critical |
| FR-05 | WelcomeScreen содержит кнопку Continue | `[AC-01] given WelcomeScreen → ElevatedButton с ключом kWelcomeContinueBtn` | Critical |
| FR-05 | Continue disabled при пустом поле | `given поле пустое when render then Continue disabled` | Critical |
| FR-05 | Continue disabled при пробелах | `given поле содержит только пробелы then Continue disabled` | High |
| FR-05 | Continue enabled при непустом вводе | `given введено "Alice" then Continue enabled` | Critical |
| FR-05 | Continue enabled при 1 символе | `given введён "A" then Continue enabled` | High |
| FR-05 | Continue enabled при Unicode | `given введено "Алиса" then Continue enabled` | High |
| FR-05 | Continue enabled при 50 символах | `given введено 50 символов then Continue enabled` | Medium |
| FR-05 | Trim: пробелы вокруг имени → enabled | `given " Alice " (пробелы вокруг) then Continue enabled` | High |
| FR-05 | Trim: ведущие/хвостовые пробелы удаляются | `given " Alice " then trimmed value = "Alice"` | High |
| FR-06 | Нажатие Continue вызывает saveUserName | `given "Alice" введено when Continue нажат then UserService.saveUserName вызван` | Critical |
| FR-06 | saveUserName вызывается с trim()-значением | `given " Bob " when Continue нажат then saveUserName("Bob") без пробелов` | High |
| FR-06 | После сохранения → переход на MainScreen | `given сохранение успешно then Navigator.pushReplacement → MainScreen` | Critical |
| AC-16 | Переход через pushReplacement (без Back) | `given навигация на MainScreen then тип навигации = pushReplacement` | Critical |
| AC-02 | Back navigation заблокирована | `given WelcomeScreen показан when back нажат then остаёмся на WelcomeScreen` | Critical |
| FR-06 | Supabase ошибка → SnackBar, экран остаётся | `[EC-03] given Supabase упал when Continue нажат then SnackBar виден` | Critical |
| FR-06 | Supabase ошибка → WelcomeScreen не исчезает | `[EC-03] given Supabase упал then WelcomeScreen всё ещё виден` | Critical |
| NFR-05 | Loading indicator во время сохранения | `given Continue нажат then CircularProgressIndicator виден` | Medium |
| NFR-04 | Поле ввода: maxLength = 50 | `given WelcomeScreen then TextField.maxLength = 50` | Medium |

### app_routing_test.dart

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-04 / FR-07 | Нет имени → WelcomeScreen | `[AC-01] given prefs пустые then WelcomeScreen` | Critical |
| FR-07 | userId есть, имени нет → WelcomeScreen | `given myUserId есть, user_name нет then WelcomeScreen` | Critical |
| FR-07 | user_name = "" → WelcomeScreen | `given user_name = "" then WelcomeScreen` | High |
| AC-01 | WelcomeScreen: поле пустое, кнопка disabled | `[AC-01] given WelcomeScreen показан then поле пустое И кнопка disabled` | Critical |
| AC-03 | Имя = "Alice" → MainScreen | `[AC-03] given user_name = "Alice" then MainScreen` | Critical |
| FR-07 | Unicode имя → MainScreen | `given user_name = "Алиса" then MainScreen` | High |
| FR-07 | 1 символ → MainScreen | `given user_name = "A" then MainScreen` | Medium |
| FR-07 | 50 символов → MainScreen | `given user_name = 50 символов then MainScreen` | Medium |
| EC-11 | Legacy userId, нет user_name → WelcomeScreen | `[EC-11] given myUserId = "LEGACY01", нет user_name then WelcomeScreen` | Critical |
| EC-11 | Legacy после ввода имени → MainScreen | `[EC-11] given myUserId + user_name = "Bob" then MainScreen` | High |
| FR-07 | Async loading state | `given MyApp запущен when hasUserName() async then loading indicator` | Medium |
| EC-10 | Язык "zh" + имя есть → MainScreen | `given user_name + language = "zh" then MainScreen` | Medium |
| EC-10 | Язык "en" + нет имени → WelcomeScreen | `given language = "en", нет user_name then WelcomeScreen` | Medium |

## Зоны риска

1. **Back navigation (AC-02, AC-16):** WelcomeScreen должен использовать `PopScope(canPop: false)` или `WillPopScope`. Без этого пользователь сможет нажать Back и попасть на пустой стек.

2. **pushReplacement vs push (AC-16):** Навигация на MainScreen через `push` создаёт стек WelcomeScreen → MainScreen. Нужен `pushReplacement` чтобы WelcomeScreen удалился из стека. Тесты проверяют `TestNavigatorObserver.hasNavigatedViaReplace`.

3. **Supabase-изоляция в тестах:** MyApp не должен инициализировать Supabase/OneSignal в initState — иначе тесты упадут без мокирования всего SDK. Роутинг должен зависеть только от `UserService.hasUserName()` → SharedPreferences.

4. **Trim-семантика (FR-05):** Continue должна быть enabled если `controller.text.trim().isNotEmpty`. Поле содержащее только пробелы = недопустимое имя.

5. **Loading state (NFR-05):** Пока `UserService.saveUserName` выполняется, кнопка должна быть заблокирована и виден CircularProgressIndicator. Иначе двойной клик может вызвать двойное сохранение.

6. **Потеря состояния при ошибке:** После ошибки Supabase TextField должен сохранять введённый текст. Тест `EC-03` проверяет это.

## Итог

| Файл | Групп | Тест-кейсов |
|------|-------|-------------|
| `welcome_screen_widget_test.dart` | 5 | 19 |
| `app_routing_test.dart` | 5 | 13 |
| **Итого** | **10** | **32** |

**Покрытые требования:** FR-04, FR-05, FR-06, FR-07, AC-01, AC-02, AC-03, AC-16, EC-03, EC-10, EC-11, NFR-04, NFR-05
