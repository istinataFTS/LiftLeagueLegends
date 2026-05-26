import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/local/database_helper.dart';
import '../logging/app_logger.dart';
import 'performance_monitor.dart';

/// Manages app lifecycle events and performs appropriate actions.
///
/// CRITICAL FIX: Database must NOT be closed during pause/inactive states
/// as it causes DatabaseException(error database_closed) when app resumes.
/// SQLite databases should remain open throughout the app lifecycle.
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();

  factory AppLifecycleManager() => _instance;

  AppLifecycleManager._internal();

  DateTime? _lastPauseTime;
  final List<VoidCallback> _resumeCallbacks = <VoidCallback>[];
  final List<VoidCallback> _pauseCallbacks = <VoidCallback>[];

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info('App lifecycle manager initialized', category: 'lifecycle');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeCallbacks.clear();
    _pauseCallbacks.clear();

    AppLogger.info('App lifecycle manager disposed', category: 'lifecycle');
  }

  void addResumeCallback(VoidCallback callback) {
    _resumeCallbacks.add(callback);
  }

  void addPauseCallback(VoidCallback callback) {
    _pauseCallbacks.add(callback);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
        _handleAppInactive();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.hidden:
        AppLogger.debug('App hidden', category: 'lifecycle');
        break;
    }
  }

  void _handleAppResumed() {
    AppLogger.info('App resumed', category: 'lifecycle');

    if (_lastPauseTime != null) {
      final pauseDuration = DateTime.now().difference(_lastPauseTime!);

      AppLogger.info(
        'App resumed after ${pauseDuration.inSeconds}s in background',
        category: 'lifecycle',
      );

      _lastPauseTime = null;
    }

    // Ensure database connection is ready after resume
    _ensureDatabaseOpen();

    for (final callback in _resumeCallbacks) {
      try {
        callback();
      } catch (error, stackTrace) {
        AppLogger.error(
          'Error in resume callback',
          category: 'lifecycle',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    PerformanceMonitor.logMemoryUsage();
  }

  void _handleAppPaused() {
    AppLogger.info('App paused', category: 'lifecycle');

    _lastPauseTime = DateTime.now();

    for (final callback in _pauseCallbacks) {
      try {
        callback();
      } catch (error, stackTrace) {
        AppLogger.error(
          'Error in pause callback',
          category: 'lifecycle',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // CRITICAL: Do NOT close database on pause
    // Closing the database causes DatabaseException(error database_closed)
    // when app resumes. SQLite connections should remain open for the app
    // lifetime. The OS will handle cleanup when the app is terminated.
  }

  void _handleAppInactive() {
    AppLogger.debug('App inactive', category: 'lifecycle');
    // No database operations needed during inactive state
  }

  void _handleAppDetached() {
    AppLogger.warning(
      'App detached - clearing in-memory performance metrics',
      category: 'lifecycle',
    );

    // Clean up performance metrics but do NOT close database.
    // Database closing during detach can cause issues if pages try to save state.
    PerformanceMonitor.clearMetrics();
  }

  /// Ensures database is open and ready for use after app resume.
  ///
  /// This method verifies the database connection is active.
  /// DatabaseHelper singleton will automatically reinitialize if needed.
  /// On web, SQLite is not supported — this is a no-op.
  Future<void> _ensureDatabaseOpen() async {
    if (kIsWeb) return;

    try {
      // Access database to trigger initialization if needed.
      // This is a no-op if database is already open.
      await DatabaseHelper().database;

      AppLogger.debug(
        'Database connection verified after resume',
        category: 'database',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to verify database connection after resume',
        category: 'database',
        error: error,
        stackTrace: stackTrace,
      );
      // Do not rethrow - allow app to continue and handle errors at usage point.
    }
  }

  bool isSessionExpired({Duration maxIdleTime = const Duration(hours: 24)}) {
    if (_lastPauseTime == null) {
      return false;
    }

    final idleTime = DateTime.now().difference(_lastPauseTime!);
    return idleTime > maxIdleTime;
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();

    AppLogger.warning(
      'Low memory pressure signal received',
      category: 'performance',
    );

    // Clear performance metrics but NOT database connection.
    PerformanceMonitor.clearMetrics();
  }
}
