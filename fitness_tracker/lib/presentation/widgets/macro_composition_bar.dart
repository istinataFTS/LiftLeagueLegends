import 'package:flutter/material.dart';

import '../../core/themes/lift_theme.dart';

/// Stacked horizontal macro composition bar, optionally followed by a % text
/// line.
///
/// Inputs are grams; calories computed internally (protein*4, carbs*4, fats*9).
/// Bar segments animate via [AnimatedContainer] unless reduced-motion is active.
/// Division by zero (all zero grams) renders an empty (rule-coloured) track
/// and, when [showPercentages] is true, '0% PROTEIN · 0% CARBS · 0% FATS'.
class MacroCompositionBar extends StatelessWidget {
  const MacroCompositionBar({
    super.key,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
    this.showPercentages = true,
  });

  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;

  /// Whether the `41% PROTEIN · 28% CARBS · 31% FATS` caption renders beneath
  /// the bar. Log shows it (`export/07-log-macros.png`); Home's intake strip
  /// does not (`export/01-home.png`), because there the three gram values are
  /// already spelled out immediately above the bar.
  final bool showPercentages;

  static const double _barHeight = 3;

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 250);

    final double proteinCals = proteinGrams * 4;
    final double carbsCals = carbsGrams * 4;
    final double fatsCals = fatsGrams * 9;
    final double totalCals = proteinCals + carbsCals + fatsCals;

    final bool hasData = totalCals > 0;

    final double proteinFraction = hasData ? proteinCals / totalCals : 0;
    final double carbsFraction = hasData ? carbsCals / totalCals : 0;
    final double fatsFraction = hasData ? fatsCals / totalCals : 0;

    int proteinPct = 0;
    int carbsPct = 0;
    int fatsPct = 0;
    if (hasData) {
      // Round the two non-largest; assign remainder to the largest so the
      // three percentages always sum to exactly 100.
      if (proteinCals >= carbsCals && proteinCals >= fatsCals) {
        carbsPct = (carbsCals / totalCals * 100).round();
        fatsPct = (fatsCals / totalCals * 100).round();
        proteinPct = 100 - carbsPct - fatsPct;
      } else if (carbsCals >= fatsCals) {
        proteinPct = (proteinCals / totalCals * 100).round();
        fatsPct = (fatsCals / totalCals * 100).round();
        carbsPct = 100 - proteinPct - fatsPct;
      } else {
        proteinPct = (proteinCals / totalCals * 100).round();
        carbsPct = (carbsCals / totalCals * 100).round();
        fatsPct = 100 - proteinPct - carbsPct;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double w = constraints.maxWidth;
            // A single stable tree in both states: a rule-coloured track
            // sits behind a Row of keyed AnimatedContainers. When all
            // macros are zero the segments collapse to zero width and the
            // track shows through fully, visually identical to the old
            // "empty track, no segments" branch — but because the same
            // widgets (same types, same keys) persist across the
            // zero/non-zero transition, Flutter keeps the elements alive
            // and AnimatedContainer animates the width change instead of
            // popping the segments in.
            return SizedBox(
              height: _barHeight,
              width: w,
              child: Stack(
                children: <Widget>[
                  Container(
                    key: const ValueKey<String>('macro-bar-track'),
                    height: _barHeight,
                    width: w,
                    decoration: const BoxDecoration(color: LiftColors.rule),
                  ),
                  Row(
                    children: <Widget>[
                      AnimatedContainer(
                        key: const ValueKey<String>('macro-bar-protein'),
                        duration: duration,
                        width: w * proteinFraction,
                        height: _barHeight,
                        decoration: const BoxDecoration(
                          color: LiftColors.protein,
                        ),
                      ),
                      AnimatedContainer(
                        key: const ValueKey<String>('macro-bar-carbs'),
                        duration: duration,
                        width: w * carbsFraction,
                        height: _barHeight,
                        decoration: const BoxDecoration(
                          color: LiftColors.carbs,
                        ),
                      ),
                      AnimatedContainer(
                        key: const ValueKey<String>('macro-bar-fats'),
                        duration: duration,
                        width: w * fatsFraction,
                        height: _barHeight,
                        decoration: const BoxDecoration(color: LiftColors.fats),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        if (showPercentages) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '$proteinPct% PROTEIN · $carbsPct% CARBS · $fatsPct% FATS',
            style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
          ),
        ],
      ],
    );
  }
}
