import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;

import '../../../../../core/themes/app_theme.dart';
import 'log_ui_colors.dart';

/// Stacked horizontal macro composition bar + % text line.
///
/// Inputs are grams; calories computed internally (protein*4, carbs*4, fats*9).
/// Bar segments animate via [AnimatedContainer] unless reduced-motion is active.
/// Division by zero (all zero grams) renders an empty track and '0% / 0% / 0%'.
class MacroCompositionBar extends StatelessWidget {
  const MacroCompositionBar({
    super.key,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });

  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;

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

    final int proteinPct = hasData
        ? (proteinCals / totalCals * 100).round()
        : 0;
    final int carbsPct = hasData ? (carbsCals / totalCals * 100).round() : 0;
    final int fatsPct = hasData ? (fatsCals / totalCals * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double w = constraints.maxWidth;
            return SizedBox(
              height: 6,
              width: w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: <Widget>[
                    // Track background
                    Container(color: AppTheme.borderDark),
                    // Animated segment fills
                    Row(
                      children: <Widget>[
                        AnimatedContainer(
                          duration: duration,
                          width: w * proteinFraction,
                          height: 6,
                          color: LogUiColors.protein,
                        ),
                        AnimatedContainer(
                          duration: duration,
                          width: w * carbsFraction,
                          height: 6,
                          color: LogUiColors.carbs,
                        ),
                        AnimatedContainer(
                          duration: duration,
                          width: w * fatsFraction,
                          height: 6,
                          color: LogUiColors.fats,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
            children: <InlineSpan>[
              TextSpan(
                text: '$proteinPct% protein',
                style: const TextStyle(color: LogUiColors.protein),
              ),
              const TextSpan(
                text: ' · ',
                style: TextStyle(color: AppTheme.textDim),
              ),
              TextSpan(
                text: '$carbsPct% carbs',
                style: const TextStyle(color: LogUiColors.carbs),
              ),
              const TextSpan(
                text: ' · ',
                style: TextStyle(color: AppTheme.textDim),
              ),
              TextSpan(
                text: '$fatsPct% fats',
                style: const TextStyle(color: LogUiColors.fats),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
