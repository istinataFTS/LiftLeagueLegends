import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/themes/app_theme.dart';
import '../../../../../core/utils/week_date_utils.dart';
import '../../../application/nutrition_log_bloc.dart';
import 'log_ui_colors.dart';
import 'macro_composition_bar.dart';

/// Shared "Today so far" card used by the Log Macros and Meal tabs.
///
/// Renders nothing when [state] is not [DailyLogsLoaded] or its date does not
/// match [selectedDate]. Otherwise shows: header ("Today so far" / "MMM d so
/// far" + "<kcal> kcal · N logs"), three macro cells (P/C/F), and the live
/// [MacroCompositionBar].
class LogTodaySoFarCard extends StatelessWidget {
  const LogTodaySoFarCard({
    super.key,
    required this.state,
    required this.selectedDate,
  });

  final NutritionLogState state;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final NutritionLogState s = state;
    if (s is! DailyLogsLoaded) return const SizedBox.shrink();
    if (!WeekDateUtils.isSameDay(s.date, selectedDate)) {
      return const SizedBox.shrink();
    }

    final DateTime today = DateTime.now();
    final bool isToday = WeekDateUtils.isSameDay(selectedDate, today);
    final String header = isToday
        ? 'Today so far'
        : '${DateFormat('MMM d').format(selectedDate)} so far';

    final int totalCalories = s.totalCalories.round();
    final int totalProtein = s.totalProtein.round();
    final int totalCarbs = s.totalCarbs.round();
    final int totalFats = s.totalFats.round();
    final int logCount = s.logs.length;
    final String logsLabel = logCount == 1 ? '1 log' : '$logCount logs';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LogUiColors.rowSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                header,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$totalCalories kcal · $logsLabel',
                style: const TextStyle(
                  color: AppTheme.textDim,
                  fontSize: 12,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _TodayCell(
                label: AppStrings.protein,
                grams: totalProtein,
                color: LogUiColors.protein,
              ),
              _TodayCell(
                label: AppStrings.carbs,
                grams: totalCarbs,
                color: LogUiColors.carbs,
              ),
              _TodayCell(
                label: AppStrings.fats,
                grams: totalFats,
                color: LogUiColors.fats,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: isToday
                ? 'Today macro composition'
                : '${DateFormat('MMM d').format(selectedDate)} macro composition',
            child: MacroCompositionBar(
              proteinGrams: s.totalProtein,
              carbsGrams: s.totalCarbs,
              fatsGrams: s.totalFats,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCell extends StatelessWidget {
  const _TodayCell({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final int grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '${grams}g',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
        ),
      ],
    );
  }
}
