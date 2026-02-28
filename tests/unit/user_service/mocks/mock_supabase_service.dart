// ignore_for_file: subtype_of_sealed_class
import 'package:mocktail/mocktail.dart';
import 'package:emergency_app/services/supabase_service.dart';

/// Мок для Supabase-слоя, используемого в UserService.saveUserName.
///
/// Тесты ожидают, что UserService будет использовать статически инжектируемый
/// коллбек/функцию для вызова Supabase, переопределяемый в тестах:
///
///   UserService.supabaseSaveHook = (userId, name) async { ... };
///
/// или что saveUserName вызывает SupabaseService.updateUserName(userId, name),
/// которую можно замокировать.
///
/// Паттерн инжекции в UserService (рекомендуется для тестируемости):
///
///   static Future<void> Function(String userId, String name)? _supabaseSaveOverride;
///
///   @visibleForTesting
///   static void setSupabaseSaveOverride(
///     Future<void> Function(String userId, String name)? fn,
///   ) => _supabaseSaveOverride = fn;

class MockSupabasePersistence {
  final List<Map<String, String>> calls = [];
  Object? errorToThrow;

  Future<void> updateUserName(String userId, String name) async {
    calls.add({'userId': userId, 'name': name});
    if (errorToThrow != null) throw errorToThrow!;
  }

  void reset() {
    calls.clear();
    errorToThrow = null;
  }

  bool get wasCalledOnce => calls.length == 1;
  bool get wasNeverCalled => calls.isEmpty;
}
