import 'package:intl/intl.dart';

import '../../domain/entities/app_settings.dart';
import 'week_date_utils.dart';

class WeekRangeLabelFormatter {
  const WeekRangeLabelFormatter._();

  static String formatForDate(
    DateTime date, {
    required WeekStartDay weekStartDay,
    String pattern = 'MMM d',
  }) {
    final weekStart = WeekDateUtils.startOfWeek(date, weekStartDay);
    final weekEnd = WeekDateUtils.endOfWeek(date, weekStartDay);
    final formatter = DateFormat(pattern);

    return '${formatter.format(weekStart)} - ${formatter.format(weekEnd)}';
  }
}
