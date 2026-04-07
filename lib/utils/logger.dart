import 'package:flutter/foundation.dart';

/// Debug-only logger. In release builds these calls are completely
/// stripped out by the Dart compiler thanks to the kDebugMode constant.
void log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}