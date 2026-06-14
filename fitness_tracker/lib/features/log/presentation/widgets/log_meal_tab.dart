import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../domain/entities/meal.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../library/application/meal_bloc.dart';
import '../../application/nutrition_log_bloc.dart';
import 'meal_list_row.dart';
import 'shared/log_action_bar.dart';
import 'shared/log_date_pill.dart';
import 'shared/log_numeric_keypad.dart';
import 'shared/log_quick_chips.dart';
import 'shared/log_stepper_field.dart';
import 'shared/log_ui_colors.dart';

class LogMealTab extends StatefulWidget {
  const LogMealTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.showDatePill = true,
    this.onLoggedSuccess,
  });

  final DateTime? initialDate;
  final bool showSuccessFeedback;

  /// Whether to render the [LogDatePill] in the tab header. The History log
  /// bottom sheets show their own date header, so they pass `false`.
  final bool showDatePill;
  final ValueChanged<DateTime>? onLoggedSuccess;

  @override
  State<LogMealTab> createState() => _LogMealTabState();
}

class _LogMealTabState extends State<LogMealTab> {
  static const List<num> _quickGramChips = <num>[50, 100, 150, 200];
  static const int _defaultGrams = 100;

  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();

  Meal? _selectedMeal;
  int _grams = _defaultGrams;
  String _searchQuery = '';
  late DateTime _selectedDate;
  bool _logCooldownActive = false;
  bool _keypadOpen = false;
  Timer? _logCooldownTimer;

  StreamSubscription<NutritionLogUiEffect>? _nutritionEffectsSub;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    final NutritionLogBloc nutritionBloc = context.read<NutritionLogBloc>();
    _nutritionEffectsSub = nutritionBloc.effects.listen((
      NutritionLogUiEffect effect,
    ) {
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NutritionLogBloc, NutritionLogState>(
      listener: (BuildContext context, NutritionLogState state) {
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
      builder: (BuildContext context, NutritionLogState nutritionState) {
        final bool isLoading = nutritionState is NutritionLogLoading;
        final Meal? meal = _selectedMeal;
        final bool canLog = meal != null && _grams > 0 && !_logCooldownActive;

        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (widget.showDatePill) ...<Widget>[
                      Align(
                        alignment: Alignment.centerRight,
                        child: LogDatePill(
                          date: _selectedDate,
                          onDateSelected: (DateTime picked) =>
                              setState(() => _selectedDate = picked),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildMealList(context),
                  ],
                ),
              ),
            ),
            if (meal != null)
              _keypadOpen
                  ? _buildKeypadDock(meal)
                  : _buildDock(meal, canLog: canLog, isLoading: isLoading),
          ],
        );
      },
    );
  }

  // ─── Search field ─────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppStrings.searchMeals,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
        onChanged: (String value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // ─── Meal list ────────────────────────────────────────────────────────────

  Widget _buildMealList(BuildContext context) {
    return BlocBuilder<MealBloc, MealState>(
      builder: (BuildContext context, MealState state) {
        if (state is MealInitial || state is MealLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryOrange),
            ),
          );
        }

        if (state is MealError) {
          return _buildMealErrorState(context);
        }

        final List<Meal> allMeals = state is MealsLoaded
            ? state.meals
            : const <Meal>[];

        if (allMeals.isEmpty) {
          return _buildEmptyMealsState(context);
        }

        final String query = _searchQuery.toLowerCase().trim();
        final List<Meal> filtered = query.isEmpty
            ? allMeals
            : allMeals
                  .where((Meal m) => m.name.toLowerCase().contains(query))
                  .toList();

        if (filtered.isEmpty) return _buildNoResultsState();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final Meal meal in filtered)
              MealListRow(
                key: ValueKey<String>('mealRow-${meal.id}'),
                meal: meal,
                isSelected: _selectedMeal?.id == meal.id,
                onTap: () => setState(() => _selectedMeal = meal),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMealErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 40, color: AppTheme.errorRed),
          const SizedBox(height: 10),
          Text(
            AppStrings.errorLoadingMeals,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.read<MealBloc>().add(LoadMealsEvent()),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMealsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.restaurant_outlined,
            size: 40,
            color: AppTheme.textDim,
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.noMealsInLibrary,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.search_off, size: 36, color: AppTheme.textDim),
          const SizedBox(height: 8),
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

  // ─── Dock (normal + keypad) ───────────────────────────────────────────────

  Widget _buildDock(
    Meal meal, {
    required bool canLog,
    required bool isLoading,
  }) {
    return LogActionBar(
      ctaLabel: AppStrings.logMealButton,
      ctaIcon: Icons.add_circle_outline,
      canSubmit: canLog,
      isLoading: isLoading,
      onSubmit: _handleLogMeal,
      previewSlot: _buildDockPreview(meal),
    );
  }

  Widget _buildDockPreview(Meal meal) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Selected meal name + 'per <grams> g'.
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                meal.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'per $_grams g',
              style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 12,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: LogStepperField(
                key: const Key('mealGramsStepper'),
                label: AppStrings.amountGrams,
                value: _grams,
                step: 10,
                onChanged: (num v) => setState(() => _grams = v.round()),
                onTapValue: () => setState(() => _keypadOpen = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: LogQuickChips(
                  values: _quickGramChips,
                  selectedValue: _grams,
                  onSelected: (num v) => setState(() => _grams = v.round()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildThisMealPreview(meal),
      ],
    );
  }

  Widget _buildThisMealPreview(Meal meal) {
    if (_grams <= 0) return const SizedBox.shrink();

    // Per plan §4: reuse multiplier = grams / servingSizeGrams from the
    // current implementation.
    final double multiplier = _grams / meal.servingSizeGrams;
    final double protein = meal.proteinPerServing * multiplier;
    final double carbs = meal.carbsPerServing * multiplier;
    final double fats = meal.fatsPerServing * multiplier;
    final double calories = MacroCalculator.calculateCalories(
      protein: protein,
      carbs: carbs,
      fat: fats,
    );

    // % composition by calorie contribution (single text line, D5 default).
    final double pCals = protein * 4;
    final double cCals = carbs * 4;
    final double fCals = fats * 9;
    final double totalCals = pCals + cCals + fCals;
    final int pPct = totalCals == 0 ? 0 : (pCals / totalCals * 100).round();
    final int cPct = totalCals == 0 ? 0 : (cCals / totalCals * 100).round();
    final int fPct = totalCals == 0 ? 0 : (fCals / totalCals * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LogUiColors.rowSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This meal',
            style: TextStyle(
              color: AppTheme.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _previewStat(
                label: AppStrings.protein,
                value: '${protein.round()}g',
                color: LogUiColors.protein,
              ),
              _previewStat(
                label: AppStrings.carbs,
                value: '${carbs.round()}g',
                color: LogUiColors.carbs,
              ),
              _previewStat(
                label: AppStrings.fats,
                value: '${fats.round()}g',
                color: LogUiColors.fats,
              ),
              Container(width: 1, height: 22, color: AppTheme.borderDark),
              _previewStat(
                label: AppStrings.kcal,
                value: '${calories.round()}',
                color: AppTheme.primaryOrangeLight,
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: '$pPct% protein',
                  style: const TextStyle(color: LogUiColors.protein),
                ),
                const TextSpan(
                  text: ' · ',
                  style: TextStyle(color: AppTheme.textDim),
                ),
                TextSpan(
                  text: '$cPct% carbs',
                  style: const TextStyle(color: LogUiColors.carbs),
                ),
                const TextSpan(
                  text: ' · ',
                  style: TextStyle(color: AppTheme.textDim),
                ),
                TextSpan(
                  text: '$fPct% fats',
                  style: const TextStyle(color: LogUiColors.fats),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textDim, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildKeypadDock(Meal meal) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: const Border(top: BorderSide(color: AppTheme.borderDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LogNumericKeypad(
          initialValue: _grams,
          label: 'grams',
          unitSuffix: 'g',
          maxIntegerDigits: 4,
          onSubmit: (num value) => setState(() {
            _grams = value.round();
            _keypadOpen = false;
          }),
          onCancel: () => setState(() => _keypadOpen = false),
        ),
      ),
    );
  }

  // ─── Log handler ──────────────────────────────────────────────────────────

  void _handleLogMeal() {
    final Meal? meal = _selectedMeal;
    if (meal == null) return;
    if (_grams <= 0) return;

    final double multiplier = _grams / meal.servingSizeGrams;
    final double loggedProtein = meal.proteinPerServing * multiplier;
    final double loggedCarbs = meal.carbsPerServing * multiplier;
    final double loggedFat = meal.fatsPerServing * multiplier;

    final NutritionLog nutritionLog = NutritionLog(
      id: _uuid.v4(),
      mealId: meal.id,
      mealName: meal.name,
      gramsConsumed: _grams.toDouble(),
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
    final DateTime now = DateTime.now();
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
