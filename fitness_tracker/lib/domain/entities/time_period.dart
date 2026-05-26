/// Time periods for muscle visualization filtering
enum TimePeriod {
  /// Show today's workout data
  today,

  /// Show this week's accumulated data (rolling 7 days)
  week,

  /// Show this month's accumulated data (rolling 30 days)
  month,

  /// Show all-time cumulative data
  allTime,
}

/// Extension methods for TimePeriod
extension TimePeriodExtension on TimePeriod {
  /// Get display name for UI
  String get displayName {
    switch (this) {
      case TimePeriod.today:
        return 'Today';
      case TimePeriod.week:
        return 'Week';
      case TimePeriod.month:
        return 'Month';
      case TimePeriod.allTime:
        return 'All Time';
    }
  }

  /// Get date range for this period
  DateRange getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case TimePeriod.today:
        return DateRange(start: today, end: today);
      case TimePeriod.week:
        return DateRange(
          start: today.subtract(const Duration(days: 7)),
          end: today,
        );
      case TimePeriod.month:
        return DateRange(
          start: today.subtract(const Duration(days: 30)),
          end: today,
        );
      case TimePeriod.allTime:
        // Return a very old start date for all-time
        return DateRange(start: DateTime(2020, 1, 1), end: today);
    }
  }
}

/// Helper class for date ranges
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Check if a date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  /// Get number of days in this range
  int get days => end.difference(start).inDays + 1;
}
