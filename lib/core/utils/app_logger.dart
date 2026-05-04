import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Tiny structured logger. Wraps `dart:developer` so we can swap to
/// a full logger package later without touching callers.
class AppLogger {
  const AppLogger._();

  static void d(String tag, String message) {
    if (kDebugMode) dev.log(message, name: tag, level: 500);
  }

  static void i(String tag, String message) {
    dev.log(message, name: tag, level: 800);
  }

  static void w(String tag, String message) {
    dev.log(message, name: tag, level: 900);
  }

  static void e(String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    dev.log(
      message,
      name: tag,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
