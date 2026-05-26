import '../../domain/entities/app_settings.dart';

class WeekDateUtils {
  WeekDateUtils._();

  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime startOfWeek(DateTime date, WeekStartDay weekStartDay) {
    final normalized = normalizeDate(date);

    switch (weekStartDay) {
      case WeekStartDay.monday:
        return normalized.subtract(
          Duration(days: normalized.weekday - DateTime.monday),
        );
      case WeekStartDay.sunday:
        final daysFromSunday = normalized.weekday % DateTime.daysPerWeek;
        return normalized.subtract(Duration(days: daysFromSunday));
    }
  }

  static DateTime endOfWeek(DateTime date, WeekStartDay weekStartDay) {
    return startOfWeek(
      date,
      weekStartDay,
    ).add(const Duration(days: DateTime.daysPerWeek - 1));
  }

  static int leadingEmptyCellCount(
    DateTime firstDayOfMonth,
    WeekStartDay weekStartDay,
  ) {
    final normalized = normalizeDate(firstDayOfMonth);

    switch (weekStartDay) {
      case WeekStartDay.monday:
        return normalized.weekday - DateTime.monday;
      case WeekStartDay.sunday:
        return normalized.weekday % DateTime.daysPerWeek;
    }
  }

  static List<String> weekdayHeaders(WeekStartDay weekStartDay) {
    switch (weekStartDay) {
      case WeekStartDay.monday:
        return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      case WeekStartDay.sunday:
        return const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final normalizedA = normalizeDate(a);
    final normalizedB = normalizeDate(b);

    return normalizedA.year == normalizedB.year &&
        normalizedA.month == normalizedB.month &&
        normalizedA.day == normalizedB.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    final normalizedA = normalizeDate(a);
    final normalizedB = normalizeDate(b);

    return normalizedA.year == normalizedB.year &&
        normalizedA.month == normalizedB.month;
  }
}
