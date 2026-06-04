import 'package:fitness_tracker/core/utils/calendar_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarDay.startOfDay', () {
    test('returns local midnight for a date with a time component', () {
      final input = DateTime(2026, 6, 3, 14, 30, 45, 999);
      final result = CalendarDay.startOfDay(input);

      expect(result, equals(DateTime(2026, 6, 3)));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('returns the same value when already at midnight', () {
      final midnight = DateTime(2026, 3, 15);
      expect(CalendarDay.startOfDay(midnight), equals(midnight));
    });

    test('does not change the calendar date', () {
      final input = DateTime(2026, 12, 31, 23, 59, 59);
      final result = CalendarDay.startOfDay(input);

      expect(result.year, 2026);
      expect(result.month, 12);
      expect(result.day, 31);
    });
  });

  group('CalendarDay.nextDay', () {
    test('advances by exactly one calendar day and returns local midnight', () {
      final day = DateTime(2026, 6, 3);
      final next = CalendarDay.nextDay(day);

      expect(next, equals(DateTime(2026, 6, 4)));
      expect(next.hour, 0);
      expect(next.minute, 0);
      expect(next.second, 0);
    });

    test('rolls over month-end correctly (March 31 → April 1)', () {
      final lastDayOfMarch = DateTime(2026, 3, 31);
      expect(CalendarDay.nextDay(lastDayOfMarch), equals(DateTime(2026, 4, 1)));
    });

    test('rolls over year-end correctly (December 31 → January 1)', () {
      final lastDayOfYear = DateTime(2026, 12, 31);
      expect(CalendarDay.nextDay(lastDayOfYear), equals(DateTime(2027, 1, 1)));
    });

    test(
      'rolls over February correctly in a non-leap year (Feb 28 → Mar 1)',
      () {
        final feb28 = DateTime(2026, 2, 28);
        expect(CalendarDay.nextDay(feb28), equals(DateTime(2026, 3, 1)));
      },
    );

    test('rolls over February correctly in a leap year (Feb 29 → Mar 1)', () {
      final feb29 = DateTime(2028, 2, 29);
      expect(CalendarDay.nextDay(feb29), equals(DateTime(2028, 3, 1)));
    });

    test('works correctly when input has a non-zero time component', () {
      // nextDay should look at calendar date only, not elapsed time.
      final dayWithTime = DateTime(2026, 6, 3, 23, 59, 59);
      expect(CalendarDay.nextDay(dayWithTime), equals(DateTime(2026, 6, 4)));
    });
  });

  group('CalendarDay.calendarDaysBetween', () {
    test('same day returns 0', () {
      final day = DateTime(2026, 6, 3);
      expect(CalendarDay.calendarDaysBetween(day, day), 0);
    });

    test('consecutive days returns 1', () {
      final a = DateTime(2026, 6, 3);
      final b = DateTime(2026, 6, 4);
      expect(CalendarDay.calendarDaysBetween(a, b), 1);
    });

    test('reversed args returns negative', () {
      final a = DateTime(2026, 6, 4);
      final b = DateTime(2026, 6, 3);
      expect(CalendarDay.calendarDaysBetween(a, b), -1);
    });

    test('2026-02-05 to 2026-06-03 returns 118', () {
      // Independent verification:
      //   Remaining Feb days after the 5th: 28 − 5 = 23
      //   March:  31
      //   April:  30
      //   May:    31
      //   June:    3
      //   Total: 23 + 31 + 30 + 31 + 3 = 118
      final a = DateTime(2026, 2, 5);
      final b = DateTime(2026, 6, 3);
      expect(CalendarDay.calendarDaysBetween(a, b), 118);
    });

    test('ignores time-of-day (23:00 vs next-day 01:00 → 1)', () {
      // Without DST-safe UTC normalization, a local-midnight difference()
      // across a 23-h day could return 0 instead of 1.
      final a = DateTime(2026, 6, 3, 23, 0);
      final b = DateTime(2026, 6, 4, 1, 0);
      expect(CalendarDay.calendarDaysBetween(a, b), 1);
    });

    test('same day at different times returns 0', () {
      final a = DateTime(2026, 6, 3, 0, 0);
      final b = DateTime(2026, 6, 3, 23, 59, 59);
      expect(CalendarDay.calendarDaysBetween(a, b), 0);
    });

    // DST-safety contract: around the Europe/Sofia spring-forward 2026-03-29
    // (clocks jump 03:00→04:00, making that day 23 h long), calendarDaysBetween
    // must return the plain calendar-day difference.
    //
    // NOTE: on UTC CI (ubuntu-latest) these fixed dates produce the same result
    // whether or not we UTC-normalise, because UTC has no DST.  The test
    // documents the *contract* and catches regressions on any local machine
    // whose timezone observes DST.  The on-device reproduction is in
    // KNOWN_ISSUES.md #muscle-stimulus-rebuild-dst-day-iteration.
    test(
      'spanning Europe/Sofia spring-forward (2026-03-28 to 2026-03-30) → 2',
      () {
        final a = DateTime(2026, 3, 28);
        final b = DateTime(2026, 3, 30);
        expect(CalendarDay.calendarDaysBetween(a, b), 2);
      },
    );

    test('spanning a full month boundary (2026-03-15 to 2026-04-15) → 31', () {
      final a = DateTime(2026, 3, 15);
      final b = DateTime(2026, 4, 15);
      expect(CalendarDay.calendarDaysBetween(a, b), 31);
    });
  });
}
