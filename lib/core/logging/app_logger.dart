import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class AppLogger {
  const AppLogger();

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final ctx = context == null || context.isEmpty
          ? ''
          : ' context=${context.toString()}';
      final err = error == null ? '' : ' error=$error';
      final st = stackTrace == null ? '' : ' stackTrace=$stackTrace';
      debugPrint('[$timestamp] [$level] $message$ctx$err$st');
    }
  }

  void debug(String message, {Map<String, Object?>? context}) {
    log(LogLevel.debug, message, context: context);
  }

  void info(String message, {Map<String, Object?>? context}) {
    log(LogLevel.info, message, context: context);
  }

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.warning,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  void critical(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    log(
      LogLevel.critical,
      message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }
}

const appLogger = AppLogger();
