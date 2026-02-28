# Test Plan — MainScreen: отображение имени + Edit Name (Модуль 4)

## Overview

- **Модуль:** `lib/screens/main_screen.dart`
- **Цель:** Проверить отображение имени пользователя в карточке "My ID" и функциональность диалога "Edit Name" (валидация, сохранение, обновление UI, обработка ошибок)
- **Ожидаемый статус:** 🔴 **ALL TESTS ARE RED** — FR-17, FR-18, FR-19 ещё не реализованы в MainScreen

---

## ⚠️ Замечание по нумерации FR

Пользователь указал **FR-21 — FR-24** — таких требований в SPEC_VALIDATED.md v1.1 нет.
Спецификация завершается на FR-20 (SOSService). Тесты написаны по **фактическим**
требованиям MainScreen:

| Указано (ошибочно) | Фактическое | Описание |
|--------------------|-------------|----------|
| FR-21 | **FR-17** | Отображение имени над ID в карточке My ID |
| FR-22 | **FR-18** | Кнопка "Edit Name" в карточке |
| FR-23 | **FR-19** | Диалог Edit Name: предзаполнение, валидация, сохранение |
| FR-24 | не существует | — |

---

## Команды запуска

```bash
# Все тесты модуля 4
flutter test tests/unit/main_screen/ --reporter expanded

# Только тесты отображения имени
flutter test tests/unit/main_screen/ --name "FR-17"

# Только тесты диалога
flutter test tests/unit/main_screen/ --name "FR-19"

# Тесты по AC
flutter test tests/unit/main_screen/ --name "AC-04"
flutter test tests/unit/main_screen/ --name "AC-05"
flutter test tests/unit/main_screen/ --name "AC-06"
flutter test tests/unit/main_screen/ --name "AC-18"
```

## Структура файлов

```
tests/unit/main_screen/
  mocks/
    test_helpers.dart         # Ключи, buildMainScreenTestApp, setup helpers
  main_screen_test.dart       # 30 widget-тестов
  TEST_PLAN.md                # Этот документ
```

## Архитектурные контракты для реализации

### Новые поля в `_MainScreenState`

```dart
String _userName = ''; // добавить рядом с _userId

@override
void initState() {
  super.initState();
  _loadUserData(); // переименовать _loadUserId → _loadUserData
}

Future<void> _loadUserData() async {
  final userId = await UserService.getUserId();
  final userName = await UserService.getUserName(); // НОВЫЙ метод
  setState(() {
    _userId = userId;
    _userName = userName ?? '';
    _isLoading = false;
  });
}
```

### Карточка "My ID" (обновление)

```dart
// Добавить над строкой с userId:
if (_userName.isNotEmpty)
  Text(
    _userName,
    key: const Key('user_name_display'),
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  ),

// Обернуть текущий текст userId:
Text(
  _userId,
  key: const Key('user_id_display'),
  // ...существующий стиль...
),

// Добавить кнопку Edit Name:
TextButton(
  key: const Key('edit_name_button'),
  onPressed: _showEditNameDialog,
  child: const Text('Edit Name'),
),
```

### Диалог Edit Name

```dart
void _showEditNameDialog() {
  final controller = TextEditingController(text: _userName);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        key: const Key('edit_name_dialog'),
        title: const Text('Edit Name'),
        content: TextField(
          key: const Key('edit_name_field'),
          controller: controller,
          maxLength: 50,
          onChanged: (_) => setDialogState(() {}),
        ),
        actions: [
          TextButton(
            key: const Key('edit_name_cancel_button'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('edit_name_confirm_button'),
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => _confirmEditName(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmEditName(BuildContext ctx, String name) async {
  // NFR-06: SharedPreferences сохраняется ПЕРВЫМ (внутри saveUserName)
  try {
    await UserService.saveUserName(name);
  } catch (e) {
    // Supabase ошибка → SnackBar, но имя локально уже сохранено
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved locally. Sync error: $e')),
      );
    }
  }
  if (mounted) {
    Navigator.pop(ctx);
    setState(() => _userName = name); // обновить карточку без перезапуска
  }
}
```

## Матрица покрытия требований

| Требование | Описание | Тест | Приоритет |
|------------|----------|------|-----------|
| FR-17 / AC-04 | Имя "Alice" над ID | `[AC-04] given user_name = "Alice" then "Alice" above ID` | Critical |
| FR-17 | Без имени → нет виджета | `given no user_name then kUserNameDisplay absent` | Critical |
| FR-17 | Unicode "Алиса" | `given user_name = "Алиса" then shown correctly` | High |
| FR-17 | 50 символов без усечения | `given 50-char name then displayed in full` | Medium |
| FR-17 | Пустая строка "" → нет виджета | `given user_name = "" then no name widget` | High |
| FR-17 | ID отображается (регрессия) | `given userId = "ABCD1234" then kUserIdDisplay = "ABCD1234"` | Critical |
| FR-18 / AC-04 | Edit Name button при имени | `given name set then kEditNameButton present` | Critical |
| FR-18 | Edit Name button без имени | `given no name then kEditNameButton still present` | High |
| FR-18 | Кнопка нажимаема | `given button tap then dialog opens` | High |
| FR-19 / AC-05 | Диалог предзаполнен "Alice" | `[AC-05] given "Alice" then dialog opens with "Alice"` | Critical |
| FR-19 | Диалог без имени → пустой | `given no name then dialog field empty` | High |
| FR-19 | Cancel закрывает диалог | `given cancel then dialog dismissed` | Critical |
| FR-19 | Обе кнопки видны | `given dialog open then confirm + cancel visible` | Medium |
| AC-18 | Пустое поле → Confirm disabled | `[AC-18] given empty field then confirm onPressed=null` | Critical |
| AC-18 | Пробелы → Confirm disabled | `given spaces only then confirm disabled` | High |
| AC-18 | "Bob" → Confirm enabled | `given "Bob" then confirm onPressed!=null` | Critical |
| AC-18 | " Bob " → Confirm enabled | `given " Bob " then trim() → confirm enabled` | High |
| FR-19 | Предзаполненное имя → Confirm enabled | `given "Alice" pre-filled then confirm enabled at open` | Medium |
| FR-19 | Без имени → Confirm disabled при открытии | `given no name then confirm disabled immediately` | Medium |
| AC-06 | Confirm "Bob" → карточка = "Bob" | `[AC-06] given confirm "Bob" then card shows "Bob"` | Critical |
| AC-06 | Confirm "Bob" → SharedPreferences | `given confirm "Bob" then prefs user_name = "Bob"` | Critical |
| AC-06 | Confirm → Supabase вызван с userId+name | `given confirm then saveUserName(userId, "Bob")` | Critical |
| AC-06 | Trim при сохранении | `given " Bob " then saved as "Bob"` | High |
| FR-19 | Cancel → имя не изменено | `given cancel after edit then name unchanged` | Critical |
| FR-19 | Cancel → Supabase не вызван | `given cancel then saveUserName not called` | High |
| AC-18 | Cancel после очистки → имя неизменно | `[AC-18] given field cleared + cancel then "Alice" stays` | High |
| FR-19 | Повторное открытие предзаполнено "Bob" | `given name changed to "Bob" + reopen dialog then "Bob"` | High |
| NFR-06 | Supabase ошибка → карточка обновляется | `given supabase error then card shows "Bob"` | Critical |
| NFR-06 | Supabase ошибка → prefs сохранены | `given supabase error then prefs user_name = "Bob"` | Critical |
| NFR-04 | Supabase ошибка → SnackBar (нет краша) | `given supabase error then SnackBar shown` | High |
| NFR-04 | Supabase ошибка → нет краша | `given critical error then MainScreen still alive` | Critical |
| AC-06 | Обновление без Navigator.pushReplacement | `given save then no replacedRoutes in observer` | High |
| FR-17 | Повторное редактирование | `given Alice→Bob→Charlie then card shows "Charlie"` | Medium |

## Зоны риска

1. **Supabase + NFR-06 (порядок сохранения):** `saveUserName` должен сохранять в SharedPreferences ДО вызова Supabase. Тест "Supabase ошибка → prefs сохранены" проверяет именно это. Если порядок нарушен — тест упадёт.

2. **StatefulBuilder в диалоге:** Для реактивного обновления кнопки Confirm внутри диалога необходим `StatefulBuilder`. Без него `onChanged` не вызовет перерисовку кнопки и тесты AC-18 упадут.

3. **setState после async (mounted check):** После `await UserService.saveUserName(...)` нужно проверять `if (mounted)` перед `Navigator.pop` и `setState`. Иначе — падение при disposal в тестах.

4. **Регрессия существующего функционала:** MainScreen уже отображает userId, имеет Copy/Share кнопки и SOS. Добавление имени не должно сломать существующее поведение. Тест "userId отображается (регрессия)" это проверяет.

5. **Localization:** Текущий MainScreen использует hardcoded strings. При добавлении новых строк (заголовок диалога, метка кнопки) их нужно вынести в ARB (NFR-03). Для тестов hardcoded strings допустимы на данном этапе.

## Итог

| Файл | Групп | Тест-кейсов |
|------|-------|-------------|
| `main_screen_test.dart` | 6 | 30 |
| **Итого** | **6** | **30** |

**Покрытые требования:** FR-17, FR-18, FR-19, AC-04, AC-05, AC-06, AC-18, NFR-04, NFR-06
