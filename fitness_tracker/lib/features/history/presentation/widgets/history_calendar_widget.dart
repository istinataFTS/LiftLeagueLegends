import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/lift_theme.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../models/day_activity.dart';

/// The History month grid, rebuilt from frame 08 (`08-history-calendar.png`)
/// of the Deep Mist export. The export lives outside this repository and is
/// not checked in.
///
/// Everything that used to wrap this widget is gone: the rounded card, its
/// 14px radius, its fill and border, and the divider under the month header.
/// The frame shows a bare grid sitting on the app's two-tone ground, so that
/// is what this paints.
///
/// The two chevrons flanking the month name are **back**, against the frame,
/// because the swipe that replaced them was the only way to change month and
/// a swipe is invisible: nothing on the screen said the month could move. They
/// are drawn in the restyle's own language — bare [LiftColors.textDim] glyphs
/// on a 44dp square target, no button chrome — rather than the Material
/// [IconButton]s the pre-restyle grid used. An arrow whose direction is out of
/// range ([canGoPrevious] / [canGoNext] false) renders at
/// [LiftColors.textDisabled] and does not respond. The horizontal swipe is
/// kept as a second way in, and `HistoryPage` still publishes both moves as
/// semantic actions.
///
/// ### The three day states the frame distinguishes
///
/// Read off the frame's own pixels rather than its caption, which only
/// mentions two:
///
///  * **logged** — [LiftColors.textPrimary] with a 12x2 [LiftColors.actionTint]
///    underline beneath the number (frame: Aug 3, 5, 6, 8).
///  * **plain past day** — [LiftColors.textSecondary], no underline
///    (frame: Aug 4, 7, 9).
///  * **future day** — [LiftColors.textDisabled] and not tappable
///    (frame: Aug 10 onward, against a mock dated Aug 8).
///
/// Today additionally takes a square 1.5px [LiftColors.actionTint] outline
/// over an [LiftColors.actionWash] fill; the selected day takes the same fill
/// with the 2.5px active border weight, so the two remain distinguishable on
/// any day but today. The amber/green activity dots the pre-restyle grid drew
/// under each number are removed — the frame carries "was anything logged" in
/// the underline, and a second encoding of the same fact in a different hue
/// contradicts the spec's two-ramp rule.
class HistoryCalendarWidget extends StatelessWidget {
  final DateTime displayedMonth;
  final DateTime? selectedDate;
  final DateTime today;
  final Map<DateTime, DayActivity> dayActivity;
  final WeekStartDay weekStartDay;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoPrevious;
  final bool canGoNext;

  const HistoryCalendarWidget({
    super.key,
    required this.displayedMonth,
    required this.selectedDate,
    required this.today,
    required this.dayActivity,
    required this.weekStartDay,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  static const double _gutter = 20;
  static const double _dayCellHeight = 33;
  static const double _dayCellGap = 3;
  static const double _underlineWidth = 12;
  static const double _underlineHeight = 2;
  static const double _arrowTarget = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Top inset and header gap are smaller than the frame's 21/18 because
      // the month row is now 44dp tall (the arrows' touch target) rather than
      // a bare line of text; the block's overall height is unchanged.
      padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildMonthHeader(context),
          const SizedBox(height: 8),
          _buildWeekdayHeaders(context),
          const SizedBox(height: 14),
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final String monthName = DateFormat(
      'MMMM yyyy',
    ).format(displayedMonth).toUpperCase();

    return Row(
      children: <Widget>[
        _buildMonthArrow(
          keyValue: 'calendar-previous-month',
          icon: Icons.chevron_left,
          semanticLabel: 'Previous month',
          enabled: canGoPrevious,
          onTap: onPreviousMonth,
        ),
        Expanded(
          child: Text(
            monthName,
            textAlign: TextAlign.center,
            style: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
          ),
        ),
        _buildMonthArrow(
          keyValue: 'calendar-next-month',
          icon: Icons.chevron_right,
          semanticLabel: 'Next month',
          enabled: canGoNext,
          onTap: onNextMonth,
        ),
      ],
    );
  }

  Widget _buildMonthArrow({
    required String keyValue,
    required IconData icon,
    required String semanticLabel,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      // The node needs its own `onTap`: `excludeSemantics` drops the
      // GestureDetector's semantics with the rest of the subtree. Null when
      // out of range, so a disabled arrow offers no action to activate.
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          key: ValueKey<String>(keyValue),
          width: _arrowTarget,
          height: _arrowTarget,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? LiftColors.textDim : LiftColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    final List<String> weekdays = WeekDateUtils.weekdayHeaders(weekStartDay);

    return Row(
      children: weekdays
          .map((String day) {
            return Expanded(
              child: Text(
                day.toUpperCase(),
                textAlign: TextAlign.center,
                style: LiftText.labelMedium.copyWith(
                  color: LiftColors.textFaint,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final DateTime firstDayOfMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    );
    final DateTime lastDayOfMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    );

    final int leadingEmptyCells = WeekDateUtils.leadingEmptyCellCount(
      firstDayOfMonth,
      weekStartDay,
    );
    final int totalDays = lastDayOfMonth.day;
    final int totalCells = leadingEmptyCells + totalDays;
    final int rows = (totalCells / 7).ceil();

    return Column(
      children: List<Widget>.generate(rows, (int rowIndex) {
        return Padding(
          padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : _dayCellGap),
          child: Row(
            children: List<Widget>.generate(7, (int colIndex) {
              final int cellIndex = rowIndex * 7 + colIndex;
              final int dayNumber = cellIndex - leadingEmptyCells + 1;

              if (dayNumber < 1 || dayNumber > totalDays) {
                return const Expanded(child: SizedBox(height: _dayCellHeight));
              }

              final DateTime date = DateTime(
                displayedMonth.year,
                displayedMonth.month,
                dayNumber,
              );

              return Expanded(child: _buildDateCell(context, date));
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDateCell(BuildContext context, DateTime date) {
    final bool isToday = WeekDateUtils.isSameDay(date, today);
    final bool isSelected =
        selectedDate != null && WeekDateUtils.isSameDay(date, selectedDate!);
    final DateTime normalizedDate = WeekDateUtils.normalizeDate(date);
    final DayActivity activity =
        dayActivity[normalizedDate] ?? DayActivity.none;
    final bool hasActivity = activity.hasAny;

    final DateTime normalizedToday = WeekDateUtils.normalizeDate(today);
    final bool isFutureDate = normalizedDate.isAfter(normalizedToday);

    final Color numberColor = isFutureDate
        ? LiftColors.textDisabled
        : hasActivity
        ? LiftColors.textPrimary
        : LiftColors.textSecondary;

    final BoxBorder? border = isSelected
        ? Border.all(
            color: LiftColors.actionTint,
            width: LiftShape.borderWidthActive,
          )
        : isToday
        ? Border.all(color: LiftColors.actionTint, width: LiftShape.borderWidth)
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isFutureDate ? null : () => onDateSelected(normalizedDate),
      child: Semantics(
        selected: isSelected,
        button: !isFutureDate,
        label: DateFormat('EEEE, MMMM d').format(date),
        child: Container(
          height: _dayCellHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: border == null ? null : LiftColors.actionWash,
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${date.day}',
                style: LiftText.dataSmall.copyWith(
                  // Pin the line box to the glyph box. Digits have no
                  // descender, so nothing is clipped, and the cell stops
                  // depending on the font's own line height — which differs
                  // between the bundled JetBrainsMono and the fallback face
                  // `flutter_test` substitutes, by enough to overflow the
                  // 2.5px-bordered selected cell by a pixel.
                  height: 1,
                  color: numberColor,
                  fontFeatures: LiftText.dataFeatures,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: _underlineWidth,
                height: _underlineHeight,
                child: hasActivity
                    ? const ColoredBox(color: LiftColors.actionTint)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
