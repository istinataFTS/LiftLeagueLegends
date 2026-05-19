import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../domain/entities/meal.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../library/application/meal_bloc.dart';
import '../../application/nutrition_log_bloc.dart';

class LogMealTab extends StatefulWidget {
  final DateTime? initialDate;
  final bool showSuccessFeedback;
  final ValueChanged<DateTime>? onLoggedSuccess;

  const LogMealTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.onLoggedSuccess,
  });

  @override
  State<LogMealTab> createState() => _LogMealTabState();
}

class _LogMealTabState extends State<LogMealTab> {
  Meal? _selectedMeal;
  final _gramsController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _uuid = const Uuid();
  late DateTime _selectedDate;
  bool _logCooldownActive = false;
  Timer? _logCooldownTimer;

  StreamSubscription<NutritionLogUiEffect>? _nutritionEffectsSub;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    final nutritionBloc = context.read<NutritionLogBloc>();
    _nutritionEffectsSub = nutritionBloc.effects.listen((effect) {
      if (!mounted) return;

      if (effect is NutritionLogSuccessEffect) {
        if (widget.showSuccessFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(effect.message),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }

        widget.onLoggedSuccess?.call(_selectedDate);

        // Retain form values — short cooldown prevents accidental double-log.
        setState(() => _logCooldownActive = true);
        _logCooldownTimer?.cancel();
        _logCooldownTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _logCooldownActive = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _nutritionEffectsSub?.cancel();
    _logCooldownTimer?.cancel();
    _gramsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NutritionLogBloc, NutritionLogState>(
      listener: (context, state) {
        if (state is NutritionLogError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      },
      builder: (context, nutritionState) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMealSelector(context),
                    if (_selectedMeal != null) ...[
                      const SizedBox(height: 20),
                      _buildAmountInput(),
                      const SizedBox(height: 20),
                      _buildDatePicker(context),
                      const SizedBox(height: 24),
                      _buildNutritionPreview(),
                    ],
                  ],
                ),
              ),
            ),
            _buildLogButton(nutritionState),
          ],
        );
      },
    );
  }

  Widget _buildMealSelector(BuildContext context) {
    return BlocBuilder<MealBloc, MealState>(
      builder: (context, state) {
        if (state is MealInitial || state is MealLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryOrange),
          );
        }

        if (state is MealError) {
          return _buildMealErrorState(context);
        }

        final allMeals = state is MealsLoaded ? state.meals : <Meal>[];

        if (allMeals.isEmpty) {
          return _buildEmptyMealsState(context);
        }

        final filteredMeals = _searchQuery.isEmpty
            ? allMeals
            : allMeals
                  .where(
                    (meal) => meal.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
                  )
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.selectMeal,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.searchMeals,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (filteredMeals.isEmpty)
              _buildNoResultsState()
            else
              ...filteredMeals.map((meal) => _buildMealCard(meal)),
          ],
        );
      },
    );
  }

  Widget _buildMealErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
          const SizedBox(height: 12),
          Text(
            AppStrings.errorLoadingMeals,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              context.read<MealBloc>().add(LoadMealsEvent());
            },
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMealsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.restaurant_outlined,
            size: 48,
            color: AppTheme.textDim,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.noMealsInLibrary,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.createMealsInLibrary,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: AppTheme.textDim),
          const SizedBox(height: 12),
          Text(
            'No meals found',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(Meal meal) {
    final isSelected = _selectedMeal?.id == meal.id;
    final calculatedCalories = MacroCalculator.calculateCalories(
      protein: meal.proteinPerServing,
      carbs: meal.carbsPerServing,
      fat: meal.fatsPerServing,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppTheme.primaryOrange.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryOrange : AppTheme.borderDark,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMeal = meal;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.primaryOrange : null,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryOrange,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${AppStrings.per100g}: ${meal.servingSizeGrams}g',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroChip(
                    label: AppStrings.protein,
                    value: '${meal.proteinPerServing.toStringAsFixed(1)}g',
                    color: Colors.blue,
                  ),
                  _buildMacroChip(
                    label: AppStrings.carbs,
                    value: '${meal.carbsPerServing.toStringAsFixed(1)}g',
                    color: Colors.green,
                  ),
                  _buildMacroChip(
                    label: AppStrings.fats,
                    value: '${meal.fatsPerServing.toStringAsFixed(1)}g',
                    color: Colors.orange,
                  ),
                  _buildMacroChip(
                    label: AppStrings.kcal,
                    value: calculatedCalories.round().toString(),
                    color: AppTheme.primaryOrange,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
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

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.amountGrams,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gramsController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: AppStrings.amountGramsHint,
            prefixIcon: const Icon(Icons.straighten),
            suffixText: AppStrings.grams,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Log Date',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionPreview() {
    if (_selectedMeal == null || _gramsController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final grams = int.tryParse(_gramsController.text) ?? 0;
    if (grams <= 0) return const SizedBox.shrink();

    final multiplier = grams / _selectedMeal!.servingSizeGrams;
    final protein = _selectedMeal!.proteinPerServing * multiplier;
    final carbs = _selectedMeal!.carbsPerServing * multiplier;
    final fats = _selectedMeal!.fatsPerServing * multiplier;
    final calories = MacroCalculator.calculateCalories(
      protein: protein,
      carbs: carbs,
      fat: fats,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Nutrition for ${grams}g',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionItem(
                label: AppStrings.protein,
                value: '${protein.toStringAsFixed(1)}g',
                color: Colors.blue,
              ),
              _buildNutritionItem(
                label: AppStrings.carbs,
                value: '${carbs.toStringAsFixed(1)}g',
                color: Colors.green,
              ),
              _buildNutritionItem(
                label: AppStrings.fats,
                value: '${fats.toStringAsFixed(1)}g',
                color: Colors.orange,
              ),
              _buildNutritionItem(
                label: AppStrings.calories,
                value: '${calories.round()}',
                color: AppTheme.primaryOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMedium, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLogButton(NutritionLogState state) {
    final isLoading = state is NutritionLogLoading;
    final canLog =
        _selectedMeal != null &&
        _gramsController.text.isNotEmpty &&
        (int.tryParse(_gramsController.text) ?? 0) > 0 &&
        !_logCooldownActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (canLog && !isLoading) ? _handleLogMeal : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    AppStrings.logMealButton,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryOrange,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textLight,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleLogMeal() {
    if (_selectedMeal == null) return;

    final grams = int.parse(_gramsController.text);
    final multiplier = grams / _selectedMeal!.servingSizeGrams;
    final loggedProtein = _selectedMeal!.proteinPerServing * multiplier;
    final loggedCarbs = _selectedMeal!.carbsPerServing * multiplier;
    final loggedFat = _selectedMeal!.fatsPerServing * multiplier;

    final nutritionLog = NutritionLog(
      id: _uuid.v4(),
      mealId: _selectedMeal!.id,
      mealName: _selectedMeal!.name,
      gramsConsumed: grams.toDouble(),
      proteinGrams: loggedProtein,
      carbsGrams: loggedCarbs,
      fatGrams: loggedFat,
      calories: MacroCalculator.calculateCalories(
        protein: loggedProtein,
        carbs: loggedCarbs,
        fat: loggedFat,
      ),
      loggedAt: _combineDateWithCurrentTime(_selectedDate),
      createdAt: DateTime.now(),
    );

    context.read<NutritionLogBloc>().add(AddNutritionLogEvent(nutritionLog));
  }

  DateTime _combineDateWithCurrentTime(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }
}
