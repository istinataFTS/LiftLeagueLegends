import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../history_strings.dart';
import '../models/day_activity.dart';

class HistoryCalendarWidget extends StatelessWidget {
  final DateTime displayedMonth;
  final DateTime? selectedDate;
  final DateTime today;
  final Map<DateTime, DayActivity> dayActivity;
  final WeekStartDay weekStartDay;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTodayTapped;

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
    required this.onTodayTapped,
  });

  static const double _monthHeaderHeight = 52;
  static const double _weekdayHeaderHeight = 28;
  static const double _dayItemHeight = 36;
  static const double _todayBorderWidth = 1.5;
  static const double _indicatorSize = 5;
  static const double _indicatorSpacing = 3;
  static const Color _exerciseDotColor = AppTheme.warningAmber;
  static const Color _nutritionDotColor = AppTheme.successGreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildMonthHeader(context),
          const Divider(height: 1),
          _buildWeekdayHeaders(context),
          _buildCalendarGrid(context),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final String monthName = DateFormat('MMMM yyyy').format(displayedMonth);
    final bool isCurrentMonth = WeekDateUtils.isSameMonth(
      displayedMonth,
      today,
    );

    return SizedBox(
      height: _monthHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 22),
              onPressed: onPreviousMonth,
              tooltip: HistoryStrings.previousMonthTooltip,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                monthName,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!isCurrentMonth)
              TextButton(
                onPressed: onTodayTapped,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(HistoryStrings.today),
              )
            else
              const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 22),
              onPressed: onNextMonth,
              tooltip: HistoryStrings.nextMonthTooltip,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    final List<String> weekdays = WeekDateUtils.weekdayHeaders(weekStartDay);

    return SizedBox(
      height: _weekdayHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: weekdays
              .map((String day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textDim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        children: List<Widget>.generate(rows, (int rowIndex) {
          return Row(
            children: List<Widget>.generate(7, (int colIndex) {
              final int cellIndex = rowIndex * 7 + colIndex;
              final int dayNumber = cellIndex - leadingEmptyCells + 1;

              if (dayNumber < 1 || dayNumber > totalDays) {
                return const Expanded(child: SizedBox());
              }

              final DateTime date = DateTime(
                displayedMonth.year,
                displayedMonth.month,
                dayNumber,
              );

              return Expanded(child: _buildDateCell(context, date));
            }),
          );
        }),
      ),
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

    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = AppTheme.primaryOrange.withValues(alpha: 0.2);
    } else if (hasActivity) {
      backgroundColor = AppTheme.primaryOrange.withValues(alpha: 0.08);
    }

    Color? borderColor;
    if (isToday) {
      borderColor = AppTheme.primaryOrange;
    } else if (isSelected) {
      borderColor = AppTheme.primaryOrange.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: isFutureDate ? null : () => onDateSelected(normalizedDate),
      child: Container(
        height: _dayItemHeight,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderColor != null
              ? Border.all(
                  color: borderColor,
                  width: isToday ? _todayBorderWidth : 1,
                )
              : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                '${date.day}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isFutureDate
                      ? AppTheme.textDim
                      : hasActivity
                      ? AppTheme.textLight
                      : AppTheme.textMedium,
                  fontWeight: isToday || hasActivity
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (hasActivity)
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: _ActivityIndicators(activity: activity),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityIndicators extends StatelessWidget {
  const _ActivityIndicators({required this.activity});

  final DayActivity activity;

  @override
  Widget build(BuildContext context) {
    final List<Widget> dots = <Widget>[];
    if (activity.hasExercise) {
      dots.add(const _Dot(color: HistoryCalendarWidget._exerciseDotColor));
    }
    if (activity.hasNutrition) {
      if (dots.isNotEmpty) {
        dots.add(
          const SizedBox(width: HistoryCalendarWidget._indicatorSpacing),
        );
      }
      dots.add(const _Dot(color: HistoryCalendarWidget._nutritionDotColor));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: dots,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HistoryCalendarWidget._indicatorSize,
      height: HistoryCalendarWidget._indicatorSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
