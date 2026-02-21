import 'package:flutter/foundation.dart';

/// Log levels for filtering output.
enum LogLevel { debug, info, warning, error }

/// Centralized logging service with log levels and production safety.
///
/// Usage:
/// ```dart
/// Log.d('ServiceName', 'Debug message');
/// Log.i('ServiceName', 'Info message');
/// Log.w('ServiceName', 'Warning message');
/// Log.e('ServiceName', 'Error message', error);
/// ```
class Log {
  /// Minimum log level. In debug mode, all logs are shown.
  /// In release mode, only warnings and errors are shown.
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Whether to include timestamps in log output.
  static bool showTimestamp = false;

  static void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  static void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  static void e(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    _log(LogLevel.error, tag, message, error, stack);
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (level.index < minLevel.index) return;

    final timestamp = showTimestamp
        ? '${DateTime.now().toIso8601String()} '
        : '';
    final output = '$timestamp[$tag] $message';

    debugPrint(output);

    if (error != null) {
      debugPrint('$timestamp[$tag] Error: $error');
    }
    if (stack != null) {
      debugPrint('$timestamp[$tag] Stack trace:\n$stack');
    }
  }
}
