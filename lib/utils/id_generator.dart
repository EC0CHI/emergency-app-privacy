import 'dart:math';

class IdGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// Генерирует уникальный ID из 8 символов (A-Z, 0-9)
  static String generate() {
    return List.generate(8, (index) => _chars[_random.nextInt(_chars.length)])
        .join();
  }
}