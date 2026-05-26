import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/utils/week_date_utils.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';

void main() {
  group('WeekDateUtils.startOfWeek', () {
    test('returns Monday for a Monday-first week', () {
      final date = DateTime(2026, 3, 18); // Wednesday

      final result = WeekDateUtils.startOfWeek(date, WeekStartDay.monday);

      expect(result, DateTime(2026, 3, 16));
    });

    test('returns Sunday for a Sunday-first week', () {
      final date = DateTime(2026, 3, 18); // Wednesday

      final result = WeekDateUtils.startOfWeek(date, WeekStartDay.sunday);

      expect(result, DateTime(2026, 3, 15));
    });

    test('normalizes time when calculating week start', () {
      final date = DateTime(2026, 3, 18, 22, 45, 12);

      final result = WeekDateUtils.startOfWeek(date, WeekStartDay.monday);

      expect(result, DateTime(2026, 3, 16));
    });
  });

  group('WeekDateUtils.endOfWeek', () {
    test('returns Sunday for a Monday-first week', () {
      final date = DateTime(2026, 3, 18);

      final result = WeekDateUtils.endOfWeek(date, WeekStartDay.monday);

      expect(result, DateTime(2026, 3, 22));
    });

    test('returns Saturday for a Sunday-first week', () {
      final date = DateTime(2026, 3, 18);

      final result = WeekDateUtils.endOfWeek(date, WeekStartDay.sunday);

      expect(result, DateTime(2026, 3, 21));
    });
  });

  group('WeekDateUtils.leadingEmptyCellCount', () {
    test('matches Monday-first calendar layout', () {
      final firstDayOfMonth = DateTime(2026, 3, 1); // Sunday

      final result = WeekDateUtils.leadingEmptyCellCount(
        firstDayOfMonth,
        WeekStartDay.monday,
      );

      expect(result, 6);
    });

    test('matches Sunday-first calendar layout', () {
      final firstDayOfMonth = DateTime(2026, 3, 1); // Sunday

      final result = WeekDateUtils.leadingEmptyCellCount(
        firstDayOfMonth,
        WeekStartDay.sunday,
      );

      expect(result, 0);
    });
  });

  group('WeekDateUtils.weekdayHeaders', () {
    test('returns Monday-first headers', () {
      expect(WeekDateUtils.weekdayHeaders(WeekStartDay.monday), const [
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
        'S',
      ]);
    });

    test('returns Sunday-first headers', () {
      expect(WeekDateUtils.weekdayHeaders(WeekStartDay.sunday), const [
        'S',
        'M',
        'T',
        'W',
        'T',
        'F',
        'S',
      ]);
    });
  });

  group('WeekDateUtils comparisons', () {
    test('isSameDay ignores time', () {
      final morning = DateTime(2026, 3, 17, 8, 0);
      final evening = DateTime(2026, 3, 17, 19, 30);

      expect(WeekDateUtils.isSameDay(morning, evening), isTrue);
    });

    test('isSameMonth matches year and month only', () {
      final a = DateTime(2026, 3, 1);
      final b = DateTime(2026, 3, 31, 23, 59);
      final c = DateTime(2026, 4, 1);

      expect(WeekDateUtils.isSameMonth(a, b), isTrue);
      expect(WeekDateUtils.isSameMonth(a, c), isFalse);
    });

    test('normalizeDate strips time components', () {
      final date = DateTime(2026, 3, 17, 14, 22, 58);

      expect(WeekDateUtils.normalizeDate(date), DateTime(2026, 3, 17));
    });
  });
}
