import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter/services.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/meal.dart';
import 'shared/log_ui_colors.dart';

/// Compact one-line selectable meal row used by [LogMealTab].
///
/// Layout: [icon tile] · name + micro-macros `P<g> C<g> F<g>` · `<kcal> /100g`.
/// Selected state: 2 px orange border + 0.10 orange tint + orange name + trailing
/// `check_circle`. The outer padding accounts for the 1→2 px border width swap
/// so the row's total height does not jitter on selection.
class MealListRow extends StatelessWidget {
  const MealListRow({
    super.key,
    required this.meal,
    required this.isSelected,
    required this.onTap,
  });

  final Meal meal;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Inner padding compensates for the border-width delta so that the
    // overall hit-box stays the same size whether selected or not.
    final EdgeInsets contentPadding = isSelected
        ? const EdgeInsets.fromLTRB(10, 9, 10, 9)
        : const EdgeInsets.fromLTRB(11, 10, 11, 10);

    return Semantics(
      button: true,
      selected: isSelected,
      label: meal.name,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: isSelected
              ? AppTheme.primaryOrange.withValues(alpha: 0.10)
              : LogUiColors.rowSurface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: contentPadding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryOrange
                      : AppTheme.borderDark,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  // Small food icon tile (28 px).
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      size: 16,
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          meal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : AppTheme.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _MicroMacros(
                          protein: meal.proteinPer100g,
                          carbs: meal.carbsPer100g,
                          fats: meal.fatPer100g,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${meal.caloriesPer100g.round()}',
                        style: const TextStyle(
                          color: AppTheme.primaryOrangeLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        '/100g',
                        style: TextStyle(color: AppTheme.textDim, fontSize: 10),
                      ),
                    ],
                  ),
                  if (isSelected) ...<Widget>[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryOrange,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicroMacros extends StatelessWidget {
  const _MicroMacros({
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  final double protein;
  final double carbs;
  final double fats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _macro('P', protein.round(), LogUiColors.protein),
        const SizedBox(width: 8),
        _macro('C', carbs.round(), LogUiColors.carbs),
        const SizedBox(width: 8),
        _macro('F', fats.round(), LogUiColors.fats),
      ],
    );
  }

  Widget _macro(String letter, int grams, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
        children: <InlineSpan>[
          TextSpan(
            text: '$letter ',
            style: TextStyle(color: color),
          ),
          TextSpan(
            text: '${grams}g',
            style: const TextStyle(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }
}
