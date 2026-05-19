import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../domain/entities/meal.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../library/application/meal_bloc.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';

class EditNutritionLogDialog extends StatefulWidget {
  final NutritionLog log;

  const EditNutritionLogDialog({super.key, required this.log});

  @override
  State<EditNutritionLogDialog> createState() => _EditNutritionLogDialogState();
}

class _EditNutritionLogDialogState extends State<EditNutritionLogDialog> {
  late final TextEditingController _gramsController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatsController;

  bool get isMealLog => widget.log.isMealLog;

  @override
  void initState() {
    super.initState();
    _gramsController = TextEditingController(
      text: widget.log.gramsConsumed?.toStringAsFixed(0) ?? '',
    );
    _proteinController = TextEditingController(
      text: widget.log.proteinGrams.toStringAsFixed(1),
    );
    _carbsController = TextEditingController(
      text: widget.log.carbsGrams.toStringAsFixed(1),
    );
    _fatsController = TextEditingController(
      text: widget.log.fatGrams.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: Text(isMealLog ? 'Edit Meal Entry' : 'Edit Macro Entry'),
      content: SizedBox(
        width: 420,
        child: isMealLog ? _buildMealEditor(context) : _buildMacroEditor(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              isMealLog ? _saveMealLog(context) : _saveMacroLog(context),
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _buildMealEditor(BuildContext context) {
    return BlocBuilder<MealBloc, MealState>(
      builder: (BuildContext context, MealState state) {
        if (state is! MealsLoaded) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        Meal? meal;
        try {
          meal = state.meals.firstWhere(
            (Meal item) => item.id == widget.log.mealId,
          );
        } catch (_) {
          meal = null;
        }

        if (meal == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: AppTheme.errorRed,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'This meal no longer exists in your library, so this entry cannot be recalculated.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can still delete it from history.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        final double grams = double.tryParse(_gramsController.text) ?? 0.0;
        final nutrition = grams > 0 ? meal.calculateForGrams(grams) : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              meal.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gramsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                suffixText: 'g',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.25),
                ),
              ),
              child: nutrition == null
                  ? const Text('Enter grams to recalculate nutrition.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Updated nutrition',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Protein: ${nutrition.protein.toStringAsFixed(1)}g',
                        ),
                        Text('Carbs: ${nutrition.carbs.toStringAsFixed(1)}g'),
                        Text('Fats: ${nutrition.fat.toStringAsFixed(1)}g'),
                        Text('Calories: ${nutrition.calories.round()} kcal'),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMacroEditor() {
    final double protein = double.tryParse(_proteinController.text) ?? 0.0;
    final double carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final double fats = double.tryParse(_fatsController.text) ?? 0.0;

    final double calories = MacroCalculator.calculateCalories(
      protein: protein,
      carbs: carbs,
      fat: fats,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _proteinController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Protein',
            suffixText: 'g',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _carbsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Carbs',
            suffixText: 'g',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fatsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: const InputDecoration(
            labelText: 'Fats',
            suffixText: 'g',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryOrange.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            'Calories: ${calories.round()} kcal',
            style: const TextStyle(
              color: AppTheme.primaryOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _saveMealLog(BuildContext context) {
    final MealState mealState = context.read<MealBloc>().state;
    if (mealState is! MealsLoaded) {
      return;
    }

    Meal? meal;
    try {
      meal = mealState.meals.firstWhere(
        (Meal item) => item.id == widget.log.mealId,
      );
    } catch (_) {
      meal = null;
    }

    if (meal == null) {
      _showError(context, 'Meal not found in library.');
      return;
    }

    final double? grams = double.tryParse(_gramsController.text.trim());
    if (grams == null || grams <= 0) {
      _showError(context, 'Enter a valid amount in grams.');
      return;
    }

    final nutrition = meal.calculateForGrams(grams);

    final NutritionLog updatedLog = widget.log.copyWith(
      gramsConsumed: grams,
      mealName: meal.name,
      proteinGrams: nutrition.protein,
      carbsGrams: nutrition.carbs,
      fatGrams: nutrition.fat,
      calories: nutrition.calories,
    );

    context.read<HistoryBloc>().add(UpdateNutritionHistoryLogEvent(updatedLog));
    Navigator.pop(context);
  }

  void _saveMacroLog(BuildContext context) {
    final double protein =
        double.tryParse(_proteinController.text.trim()) ?? 0.0;
    final double carbs = double.tryParse(_carbsController.text.trim()) ?? 0.0;
    final double fats = double.tryParse(_fatsController.text.trim()) ?? 0.0;

    if (protein <= 0 && carbs <= 0 && fats <= 0) {
      _showError(context, 'Enter at least one macro value greater than 0.');
      return;
    }

    final NutritionLog updatedLog = widget.log.copyWith(
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fats,
      calories: MacroCalculator.calculateCalories(
        protein: protein,
        carbs: carbs,
        fat: fats,
      ),
    );

    context.read<HistoryBloc>().add(UpdateNutritionHistoryLogEvent(updatedLog));
    Navigator.pop(context);
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}
