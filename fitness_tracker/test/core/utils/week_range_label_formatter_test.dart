import 'package:fitness_tracker/core/utils/week_range_label_formatter.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeekRangeLabelFormatter', () {
    test('formats a monday-start week range', () {
      final result = WeekRangeLabelFormatter.formatForDate(
        DateTime(2026, 3, 19),
        weekStartDay: WeekStartDay.monday,
      );

      expect(result, 'Mar 16 - Mar 22');
    });

    test('formats a sunday-start week range', () {
      final result = WeekRangeLabelFormatter.formatForDate(
        DateTime(2026, 3, 19),
        weekStartDay: WeekStartDay.sunday,
      );

      expect(result, 'Mar 15 - Mar 21');
    });
  });
}
