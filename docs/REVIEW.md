# Code Review — User Name System

Reviewed files: `user_service.dart`, `guardians_service.dart`, `sos_service.dart`, `welcome_screen.dart`, `guardians_screen.dart`, `guardian_list_widget.dart`, `main_screen.dart` (name display + Edit Name dialog).

---

## Критические проблемы

### 1. FR-16 / C-04 не работает в production

**Файл:** `lib/widgets/guardian_list_widget.dart`, `lib/services/guardians_service.dart`

`GuardiansService.findUserName` перехватывает **все** исключения и возвращает `null` вместо того чтобы пробрасывать их:

```dart
// guardians_service.dart
static Future<String?> findUserName(String userId) async {
  try {
    // ... Supabase query
  } catch (_) {
    return null; // ← ВСЕ ошибки поглощаются
  }
}
```

Из-за этого блок `catch` в `GuardianListWidget._loadData` никогда не выполняется в production:

```dart
// guardian_list_widget.dart
try {
  final name = await GuardiansService.findUserName(item.id);
  return _GuardianEntry(slot: ..., name: name); // name=null при сетевой ошибке
} catch (_) {
  return _GuardianEntry(slot: ..., hasError: true); // ← НЕДОСТИЖИМО в production
}
```

**Последствие:** При сетевой ошибке `name = null`, `hasError = false` → отображается nickname (FR-15), а не только User ID (FR-16/C-04). Спецификация требует: _"On Supabase error → show only User ID (no nickname)"_.

`hasError = true` достижимо только через `_findUserNameOverride` в тестах, что делает тестовое покрытие FR-16 неотражающим production-поведение.

**Исправление:** `findUserName` должен пробрасывать исключения при сетевых ошибках (отличать "пользователь не найден" от "сеть недоступна").

---

### 2. `UserService.saveUserName` использует `update` вместо `upsert`

**Файл:** `lib/services/user_service.dart`

```dart
await Supabase.instance.client
    .from('users')
    .update({'name': name})
    .eq('user_id', userId);
```

Если строки с данным `user_id` нет в таблице (например, новое устройство, строка ещё не создана), `update` молча ничего не делает. Имя не сохраняется в Supabase без какого-либо сообщения об ошибке. Спецификация подразумевает `upsert`.

---

### 3. `WelcomeScreen._onContinue` сохраняет имя без `trim()`

**Файл:** `lib/screens/welcome_screen.dart`

```dart
void _onContinue() async {
  final name = _controller.text; // ← без trim()
  await UserService.saveUserName(name);
}
```

Кнопка активируется только когда `_controller.text.trim().isNotEmpty`, но само значение сохраняется с пробелами. Пользователь, введя `" Bob "`, получит имя с пробелами в карточке и в SOS-уведомлении: `"SOS Emergency from  Bob  (XXXX)"`.

`MainScreen._saveName` корректно вызывает `trim()` — поведение несогласовано.

---

## Рекомендации

### 4. Нет таймаута на вызов Edge Function

**Файл:** `lib/services/sos_service.dart`

```dart
static Future<Map<String, dynamic>> _callEdgeFunction(...) async {
  final response = await Supabase.instance.client.functions.invoke('send-sos', ...);
  // нет таймаута
}
```

SOS — экстренная функция. Зависший запрос (нестабильная сеть, перегруженный сервер) блокирует UI на неопределённое время. Рекомендуется добавить `.timeout(const Duration(seconds: 10))`.

---

### 5. NFR-03: новые строки не локализованы

**Файлы:** `main_screen.dart`, `welcome_screen.dart`, `guardians_screen.dart`

Все новые UI-строки захардкожены на английском:
- `'Edit Name'`, `'Your name'`, `'Save'`, `'Cancel'`
- `'ID copied to clipboard'`, `'Hold for 5 seconds to send SOS'`
- `'Guardian ID'`, `'Nickname'`, `'Saved locally. Sync error: $e'`

NFR-03 требует поддержки `ru`/`en`/`zh`. Строки должны быть вынесены в ARB-файлы.

---

### 6. `UserService.hasUserId()` несогласован с `getUserId()`

**Файл:** `lib/services/user_service.dart`

```dart
static Future<bool> hasUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey('myUserId'); // ← только проверка наличия ключа
}

static Future<String> getUserId() async {
  final stored = prefs.getString('myUserId') ?? '';
  if (stored.isNotEmpty) return stored; // ← проверяет и наличие, и непустоту
}
```

Если `prefs.setString('myUserId', '')` вызван по ошибке, `hasUserId()` вернёт `true`, а `getUserId()` создаст новый ID. Рекомендуется привести к единой логике.

---

### 7. `GuardiansScreen._save()` без обратной связи пользователю

**Файл:** `lib/screens/guardians_screen.dart`

```dart
ElevatedButton(
  onPressed: _save, // async, но без await и без feedback
  child: const Text('Save'),
)
```

После нажатия кнопки пользователь не получает подтверждения сохранения (нет SnackBar, нет индикатора загрузки, нет навигации назад). Ошибка записи также никак не отображается.

---

### 8. `SosService._callEdgeFunction`: небезопасный каст

**Файл:** `lib/services/sos_service.dart`

```dart
return Map<String, dynamic>.from(response.data as Map);
```

Если Edge Function вернёт пустое тело или ошибку без JSON, `response.data` будет `null` → `TypeError` в runtime. Исключение поймается внешним `catch (e)`, но сообщение будет нечитаемым. Рекомендуется: `if (response.data is! Map) return {'success': false, 'error': 'Invalid response'};`

---

### 9. `GuardianListWidget`: `shrinkWrap: true` в `ListView`

**Файл:** `lib/widgets/guardian_list_widget.dart`

`shrinkWrap: true` отключает виртуализацию ListView и рендерит все элементы сразу. При текущем лимите в 5 хранителей это не критично, но создаёт нежелательный прецедент. Рекомендуется использовать `Column` + `children: _items.map(_buildItem).toList()`.

---

## Что сделано хорошо

**Паттерн override-инъекции** (`@visibleForTesting static void setXOverride(fn?)`) применён последовательно во всех сервисах — позволяет тестировать без моков и без изменения production-кода.

**Generation counter в `GuardiansScreen`** корректно решает race condition EC-04: каждый новый поиск инкрементирует `_generations[idx]`, устаревший ответ отбрасывается при несовпадении поколения.

**`Future.wait` в `GuardianListWidget`** правильно реализует NFR-07 (параллельная загрузка): `.toList()` запускает все futures до вызова `Future.wait`, порядок результатов соответствует порядку запросов (EC-07).

**Stack-based inline dialog в `MainScreen`** — нестандартное, но функциональное решение, полностью совместимое с тестовой инфраструктурой (избегает `NavigatorObserver.didPush`).

**NFR-06 соблюдён в `UserService.saveUserName`**: SharedPreferences сохраняется до вызова Supabase — имя доступно оффлайн немедленно.

**Обработка ошибок Supabase в `UserService.saveUserName`** прозрачна для пользователя: ошибка синхронизации показывается через SnackBar, но локальное сохранение всегда происходит.

**`GuardiansScreen`** корректно реализует debounce 500ms (FR-09) и отбрасывание устаревших ответов (EC-04) для всех 5 слотов независимо.
