import 'package:intl/intl.dart';

import '../../domain/entities/app_settings.dart';
import 'week_date_utils.dart';

class WeekRangeLabelFormatter {
  const WeekRangeLabelFormatter._();

  /// Formats the week containing [date] as `<start><separator><end>`.
  ///
  /// [pattern] and [separator] both default to the original hyphenated
  /// `Mar 16 - Mar 22` form so existing callers (Settings) are unaffected.
  /// Home passes `pattern: 'MMM dd', separator: ' — '` for the zero-padded,
  /// em-dashed `Aug 03 — Aug 09` its header uppercases.
  static String formatForDate(
    DateTime date, {
    required WeekStartDay weekStartDay,
    String pattern = 'MMM d',
    String separator = ' - ',
  }) {
    final weekStart = WeekDateUtils.startOfWeek(date, weekStartDay);
    final weekEnd = WeekDateUtils.endOfWeek(date, weekStartDay);
    final formatter = DateFormat(pattern);

    return '${formatter.format(weekStart)}$separator'
        '${formatter.format(weekEnd)}';
  }
}
