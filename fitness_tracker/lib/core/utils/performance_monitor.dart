import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

class PerformanceMetricSummary {
  final String name;
  final int count;
  final int minMs;
  final int maxMs;
  final int avgMs;
  final int latestMs;

  const PerformanceMetricSummary({
    required this.name,
    required this.count,
    required this.minMs,
    required this.maxMs,
    required this.avgMs,
    required this.latestMs,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'count': count,
      'minMs': minMs,
      'maxMs': maxMs,
      'avgMs': avgMs,
      'latestMs': latestMs,
    };
  }

  @override
  String toString() {
    return 'PerformanceMetricSummary('
        'name: $name, '
        'count: $count, '
        'minMs: $minMs, '
        'maxMs: $maxMs, '
        'avgMs: $avgMs, '
        'latestMs: $latestMs'
        ')';
  }
}

class PerformanceMonitor {
  PerformanceMonitor._();

  static final Map<String, Stopwatch> _activeTimers = <String, Stopwatch>{};
  static final Map<String, ListQueue<int>> _history =
      <String, ListQueue<int>>{};

  static const int _maxHistorySize = 100;

  static void startTimer(String operation) {
    _activeTimers[operation] = Stopwatch()..start();
  }

  static Duration? endTimer(String operation) {
    final stopwatch = _activeTimers.remove(operation);
    if (stopwatch == null) {
      return null;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;
    _record(operation, duration.inMilliseconds);
    return duration;
  }

  static int stopTimer(String operation) {
    final duration = endTimer(operation);
    return duration?.inMilliseconds ?? 0;
  }

  static Future<T> trackAsync<T>(
    String operation,
    Future<T> Function() action, {
    int slowThresholdMs = 500,
    String category = 'performance',
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      return await action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _record(operation, elapsedMs);
      _logIfSlow(
        operation,
        elapsedMs,
        slowThresholdMs: slowThresholdMs,
        category: category,
      );
    }
  }

  static T trackSync<T>(
    String operation,
    T Function() action, {
    int slowThresholdMs = 16,
    String category = 'performance',
  }) {
    final stopwatch = Stopwatch()..start();

    try {
      return action();
    } finally {
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;
      _record(operation, elapsedMs);
      _logIfSlow(
        operation,
        elapsedMs,
        slowThresholdMs: slowThresholdMs,
        category: category,
      );
    }
  }

  static Future<T> trackDatabaseOperation<T>(
    String operation,
    Future<T> Function() callback,
  ) {
    return trackAsync(
      'db_$operation',
      callback,
      slowThresholdMs: 100,
      category: 'database',
    );
  }

  static Duration? getAverageDuration(String operation) {
    final samples = _history[operation];
    if (samples == null || samples.isEmpty) {
      return null;
    }

    final totalMs = samples.fold<int>(0, (sum, value) => sum + value);
    return Duration(milliseconds: totalMs ~/ samples.length);
  }

  static PerformanceMetricSummary? getSummary(String operation) {
    final samples = _history[operation];
    if (samples == null || samples.isEmpty) {
      return null;
    }

    final values = samples.toList(growable: false);
    final totalMs = values.fold<int>(0, (sum, value) => sum + value);
    final minMs = values.reduce((a, b) => a < b ? a : b);
    final maxMs = values.reduce((a, b) => a > b ? a : b);
    final latestMs = values.last;

    return PerformanceMetricSummary(
      name: operation,
      count: values.length,
      minMs: minMs,
      maxMs: maxMs,
      avgMs: totalMs ~/ values.length,
      latestMs: latestMs,
    );
  }

  static Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};

    for (final entry in _history.entries) {
      final summary = getSummary(entry.key);
      if (summary != null) {
        report[entry.key] = summary.toJson();
      }
    }

    return report;
  }

  static void logSummary(String operation, {String category = 'performance'}) {
    final summary = getSummary(operation);
    if (summary == null) {
      return;
    }

    AppLogger.info(
      'Metric "$operation": '
      'latest=${summary.latestMs}ms, '
      'avg=${summary.avgMs}ms, '
      'min=${summary.minMs}ms, '
      'max=${summary.maxMs}ms, '
      'count=${summary.count}',
      category: category,
    );
  }

  static void logMemoryUsage() {
    if (!kDebugMode) {
      return;
    }

    AppLogger.debug(
      'Memory monitoring requested, but platform-specific memory tracking is not configured yet.',
      category: 'performance',
    );
  }

  static void trackScreenTransition(String from, String to) {
    AppLogger.debug(
      'Navigation transition: $from -> $to',
      category: 'navigation',
    );
  }

  static void logMetricsSnapshot({String category = 'performance'}) {
    final report = getPerformanceReport();
    if (report.isEmpty) {
      AppLogger.debug(
        'No performance metrics collected yet',
        category: category,
      );
      return;
    }

    AppLogger.info('Performance metrics snapshot: $report', category: category);
  }

  static void clearMetrics() {
    _activeTimers.clear();
    _history.clear();
  }

  static void _record(String operation, int elapsedMs) {
    final bucket = _history.putIfAbsent(
      operation,
      () => ListQueue<int>(_maxHistorySize),
    );

    if (bucket.length >= _maxHistorySize) {
      bucket.removeFirst();
    }

    bucket.addLast(elapsedMs);
  }

  static void _logIfSlow(
    String operation,
    int elapsedMs, {
    required int slowThresholdMs,
    required String category,
  }) {
    if (elapsedMs <= slowThresholdMs) {
      return;
    }

    AppLogger.warning(
      'Slow operation detected: $operation took ${elapsedMs}ms',
      category: category,
    );
  }
}
