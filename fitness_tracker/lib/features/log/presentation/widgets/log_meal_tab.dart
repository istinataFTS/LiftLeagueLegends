import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/ui/keypad_visibility_controller.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../injection/injection_container.dart';
import '../../../../domain/entities/meal.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../library/application/meal_bloc.dart';
import '../../application/nutrition_log_bloc.dart';
import 'meal_picker_sheet.dart';
import 'shared/log_action_bar.dart';
import 'shared/log_numeric_keypad.dart';
import 'shared/log_quick_chips.dart';
import 'shared/log_stepper_field.dart';
import 'shared/log_today_so_far_card.dart';
import 'shared/log_ui_colors.dart';
import 'shared/macro_composition_bar.dart';

class LogMealTab extends StatefulWidget {
  const LogMealTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.onLoggedSuccess,
  });

  final DateTime? initialDate;
  final bool showSuccessFeedback;
  final ValueChanged<DateTime>? onLoggedSuccess;

  @override
  State<LogMealTab> createState() => _LogMealTabState();
}

class _LogMealTabState extends State<LogMealTab> {
  static const List<num> _quickGramChips = <num>[50, 100, 150, 200];
  static const int _defaultGrams = 100;

  final Uuid _uuid = const Uuid();

  Meal? _selectedMeal;
  int _grams = _defaultGrams;
  late DateTime _selectedDate;
  bool _logCooldownActive = false;
  bool _keypadOpen = false;
  Timer? _logCooldownTimer;
  late final KeypadVisibilityController _keypadVisibility;

  StreamSubscription<NutritionLogUiEffect>? _nutritionEffectsSub;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();
    _keypadVisibility = sl<KeypadVisibilityController>();

    final NutritionLogBloc nutritionBloc = context.read<NutritionLogBloc>();

    // Safety-net load so Today-so-far + recents populate when the standalone
    // Log page opens this tab first. Skip if the bloc already holds this date.
    final NutritionLogState current = nutritionBloc.state;
    final bool alreadyLoadedForDate =
        current is DailyLogsLoaded &&
        WeekDateUtils.isSameDay(current.date, _selectedDate);
    if (!alreadyLoadedForDate) {
      nutritionBloc.add(LoadDailyLogsEvent(_selectedDate));
    }

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
    _keypadVisibility.hide();
    super.dispose();
  }

  void _setKeypadOpen(bool open) {
    setState(() => _keypadOpen = open);
    if (open) {
      _keypadVisibility.show();
    } else {
      _keypadVisibility.hide();
    }
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
                    _buildSelectMealBar(context, nutritionState),
                    const SizedBox(height: 16),
                    LogTodaySoFarCard(
                      state: nutritionState,
                      selectedDate: _selectedDate,
                    ),
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

  // ─── Select-meal bar (opens the picker sheet) ─────────────────────────────

  Widget _buildSelectMealBar(
    BuildContext context,
    NutritionLogState nutritionState,
  ) {
    return BlocBuilder<MealBloc, MealState>(
      builder: (BuildContext context, MealState mealState) {
        final List<Meal> meals = mealState is MealsLoaded
            ? mealState.meals
            : const <Meal>[];

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openMealPicker(context, meals, nutritionState),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedMeal?.name ?? AppStrings.selectMeal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _selectedMeal == null
                            ? AppTheme.textLight
                            : AppTheme.primaryOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, color: AppTheme.textDim),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMealPicker(
    BuildContext context,
    List<Meal> meals,
    NutritionLogState nutritionState,
  ) async {
    final List<String> recentIds = _buildRecentMealIds(nutritionState);
    final Meal? picked = await MealPickerSheet.show(
      context,
      meals: meals,
      recentMealIds: recentIds,
      selected: _selectedMeal,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _selectedMeal = picked);
    }
  }

  List<String> _buildRecentMealIds(NutritionLogState state) {
    if (state is! DailyLogsLoaded) return const <String>[];
    final List<NutritionLog> sorted = List<NutritionLog>.from(state.logs)
      ..sort(
        (NutritionLog a, NutritionLog b) => b.loggedAt.compareTo(a.loggedAt),
      );
    final Set<String> seen = <String>{};
    return sorted
        .map((NutritionLog l) => l.mealId)
        .whereType<String>()
        .where(seen.add)
        .take(5)
        .toList();
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
                onTapValue: () => _setKeypadOpen(true),
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
    if (meal.servingSizeGrams <= 0) return const SizedBox.shrink();

    final double multiplier = _grams / meal.servingSizeGrams;
    final double protein = meal.proteinPerServing * multiplier;
    final double carbs = meal.carbsPerServing * multiplier;
    final double fats = meal.fatsPerServing * multiplier;
    final double calories = MacroCalculator.calculateCalories(
      protein: protein,
      carbs: carbs,
      fat: fats,
    );

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
          const SizedBox(height: 8),
          Semantics(
            label: 'This entry macro composition',
            child: MacroCompositionBar(
              proteinGrams: protein,
              carbsGrams: carbs,
              fatsGrams: fats,
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
          onSubmit: (num value) {
            setState(() => _grams = value.round());
            _setKeypadOpen(false);
          },
          onCancel: () => _setKeypadOpen(false),
        ),
      ),
    );
  }

  // ─── Log handler ──────────────────────────────────────────────────────────

  void _handleLogMeal() {
    final Meal? meal = _selectedMeal;
    if (meal == null) return;
    if (_grams <= 0) return;
    if (meal.servingSizeGrams <= 0) return;

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
