import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/themes/lift_number.dart';
import '../../../../../core/themes/lift_theme.dart';
import '../../../../../core/utils/week_date_utils.dart';
import '../../../../../presentation/widgets/macro_composition_bar.dart';
import '../../../application/nutrition_log_bloc.dart';
import 'macro_label.dart';

/// Shared "Today so far" block used by the Log Macros and Meal tabs.
///
/// Renders nothing when [state] is not [DailyLogsLoaded] or its date does not
/// match [selectedDate]. Otherwise shows: header ("TODAY SO FAR" / "MMM d SO
/// FAR" + "<kcal> KCAL · N LOGS"), three macro cells (P/C/F), and the live
/// [MacroCompositionBar]. Sits directly on the ground, bounded top and bottom
/// by a hairline rule — no card, no fill, no radius.
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
      key: const ValueKey<String>('log-today-so-far-block'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
          bottom: BorderSide(
            color: LiftColors.rule,
            width: LiftShape.borderWidth,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  header.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: LiftText.labelLarge.copyWith(
                    color: LiftColors.textStrong,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    '$totalCalories',
                    style: LiftText.dataSmall.copyWith(
                      color: LiftColors.textPrimary,
                      fontFeatures: LiftText.dataFeatures,
                    ),
                  ),
                  Text(
                    ' KCAL · ${logsLabel.toUpperCase()}',
                    style: LiftText.labelLarge.copyWith(
                      color: LiftColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _TodayCell(kind: MacroKind.protein, grams: totalProtein),
              ),
              Expanded(
                child: _TodayCell(kind: MacroKind.carbs, grams: totalCarbs),
              ),
              Expanded(
                child: _TodayCell(kind: MacroKind.fats, grams: totalFats),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
  const _TodayCell({required this.kind, required this.grams});

  final MacroKind kind;
  final int grams;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        LiftNumber(
          '$grams',
          'g',
          LiftText.dataMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        MacroLabel(
          kind: kind,
          swatchKey: ValueKey<String>('today-swatch-${kind.name}'),
        ),
      ],
    );
  }
}
