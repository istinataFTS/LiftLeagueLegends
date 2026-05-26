import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static void debug(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.debug,
      message,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.info,
      message,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warning(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.warning,
      message,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    String category = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      AppLogLevel.error,
      message,
      category: category,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log(
    AppLogLevel level,
    String message, {
    required String category,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formattedMessage =
        '[${level.name.toUpperCase()}][$category] $message';

    developer.log(
      formattedMessage,
      name: 'fitness_tracker',
      level: _developerLevelFor(level),
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      debugPrint(formattedMessage);

      if (error != null) {
        debugPrint('[$category] error: $error');
      }

      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  static int _developerLevelFor(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return 500;
      case AppLogLevel.info:
        return 800;
      case AppLogLevel.warning:
        return 900;
      case AppLogLevel.error:
        return 1000;
    }
  }
}
