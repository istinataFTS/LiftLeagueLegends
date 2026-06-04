/// DST-safe calendar-day arithmetic.
///
/// All helpers operate on the **calendar date** (year/month/day) and ignore
/// the time-of-day, so daylight-saving transitions (a 23-h or 25-h local day)
/// can never skew a day count or push an iterator off local midnight.
///
/// Why this exists: `RebuildMuscleStimulusFromWorkoutHistory` previously
/// stepped its day loop with `day.add(const Duration(days: 1))`. Across the
/// spring-forward boundary that adds exactly 24 h of elapsed time lands the
/// loop variable at 01:00 instead of midnight, so lookups into midnight-keyed
/// maps miss and every post-transition day's stimulus is dropped.
/// See KNOWN_ISSUES.md `#muscle-stimulus-rebuild-dst-day-iteration`.
class CalendarDay {
  const CalendarDay._();

  /// Returns the local midnight of [date]'s calendar day, stripping any
  /// time-of-day component.
  ///
  /// Equivalent to `DateTime(date.year, date.month, date.day)`.
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Returns the local midnight of the calendar day after [date].
  ///
  /// Uses component-based construction (`DateTime(y, m, d + 1)`) rather than
  /// adding a fixed [Duration], so the result is always local midnight
  /// regardless of DST transitions (unlike `date.add(const Duration(days: 1))`
  /// which can land at 01:00 across a spring-forward).
  /// Dart automatically rolls over month- and year-end boundaries.
  static DateTime nextDay(DateTime date) =>
      DateTime(date.year, date.month, date.day + 1);

  /// Returns the number of whole calendar days from [a] to [b] (i.e. b − a),
  /// ignoring time-of-day. Positive when [b] is the later date.
  ///
  /// DST-safe: compares **UTC** midnights built from the calendar components,
  /// so a 23-h or 25-h local day never skews the count. A local-midnight
  /// `.difference().inDays` would return 29 or 31 across a DST transition;
  /// UTC midnights cannot drift. See KNOWN_ISSUES.md
  /// `#muscle-stimulus-rebuild-dst-day-iteration`.
  static int calendarDaysBetween(DateTime a, DateTime b) {
    final DateTime ua = DateTime.utc(a.year, a.month, a.day);
    final DateTime ub = DateTime.utc(b.year, b.month, b.day);
    return ub.difference(ua).inDays;
  }
}
