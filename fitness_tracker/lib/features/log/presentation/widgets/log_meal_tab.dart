import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../domain/entities/meal.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../../presentation/widgets/macro_composition_bar.dart';
import '../../../library/application/meal_bloc.dart';
import '../../application/nutrition_log_bloc.dart';
import 'meal_picker_sheet.dart';
import 'shared/log_action_bar.dart';
import 'shared/log_numeric_keypad.dart';
import 'shared/log_quick_chips.dart';
import 'shared/log_stepper_field.dart';
import 'shared/log_today_so_far_card.dart';
import 'shared/macro_label.dart';

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

  /// Frame 04's literal empty-selection copy (design spec §5.3) — not
  /// `AppStrings.selectMeal` ("Select Meal"), which is the picker-sheet
  /// trigger label used elsewhere pre-restyle.
  static const String _selectFoodPrompt = 'Select a food';

  final Uuid _uuid = const Uuid();

  Meal? _selectedMeal;
  int _grams = _defaultGrams;
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
              backgroundColor: LiftColors.success,
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
    super.dispose();
  }

  void _setKeypadOpen(bool open) {
    setState(() => _keypadOpen = open);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NutritionLogBloc, NutritionLogState>(
      listener: (BuildContext context, NutritionLogState state) {
        if (state is NutritionLogError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: LiftColors.error,
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
              child: meal == null
                  ? _buildEmptySelectionBody(context, nutritionState)
                  : SingleChildScrollView(
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
            meal != null && _keypadOpen
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'FOOD',
              style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openMealPicker(context, meals, nutritionState),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _selectedMeal?.name ?? _selectFoodPrompt,
                        style: LiftText.headlineMedium.copyWith(
                          color: _selectedMeal == null
                              ? LiftColors.textFaint
                              : LiftColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more, color: LiftColors.textDim),
                  ],
                ),
              ),
            ),
          ],
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

  // ─── Empty selection body ──────────────────────────────────────────────────

  /// No meal selected yet — the select bar and today-so-far block render as
  /// usual, and the remaining blank space between them and the CTA expands to
  /// hold one centred dim prompt (design spec §5.3) instead of a fixed-height
  /// dock tucked under the heading.
  Widget _buildEmptySelectionBody(
    BuildContext context,
    NutritionLogState nutritionState,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSelectMealBar(context, nutritionState),
          const SizedBox(height: 16),
          LogTodaySoFarCard(state: nutritionState, selectedDate: _selectedDate),
          Expanded(
            child: Center(
              child: Text(
                AppStrings.pickFoodToStartEntry,
                textAlign: TextAlign.center,
                style: LiftText.bodyLarge.copyWith(color: LiftColors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dock (normal + keypad) ────────────────────────────────────────────────

  Widget _buildDock(
    Meal? meal, {
    required bool canLog,
    required bool isLoading,
  }) {
    return LogActionBar(
      ctaLabel: AppStrings.logMealButton,
      ctaIcon: Icons.add_circle_outline,
      canSubmit: canLog,
      isLoading: isLoading,
      onSubmit: _handleLogMeal,
      previewSlot: meal != null ? _buildDockPreview(meal) : null,
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
                style: LiftText.titleSmall.copyWith(
                  color: LiftColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'per $_grams g',
              style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _previewStat(
                kind: MacroKind.protein,
                valueWidget: LiftNumber.of(
                  protein.round(),
                  'g',
                  LiftText.dataMeta,
                ),
              ),
              _previewStat(
                kind: MacroKind.carbs,
                valueWidget: LiftNumber.of(
                  carbs.round(),
                  'g',
                  LiftText.dataMeta,
                ),
              ),
              _previewStat(
                kind: MacroKind.fats,
                valueWidget: LiftNumber.of(
                  fats.round(),
                  'g',
                  LiftText.dataMeta,
                ),
              ),
              Container(width: 1, height: 22, color: LiftColors.hairline),
              // Static value — never actionTint (that role signals something
              // interactive/active), matching frame 06's white "59 KCAL" and
              // frame 07's white "145 KCAL THIS ENTRY" hero.
              _previewStat(
                label: AppStrings.kcal,
                valueWidget: Text(
                  '${calories.round()}',
                  style: LiftText.dataMeta.copyWith(
                    color: LiftColors.textPrimary,
                    fontFeatures: LiftText.dataFeatures,
                  ),
                ),
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

  /// One entry-preview stat. The value stays neutral white — per frame 06 the
  /// macro's identity is carried by the [MacroLabel] swatch beside its
  /// label, not by tinting the numeral. Pass [kind] for a macro row (renders
  /// the shared swatch+caption); pass [label] alone for the non-macro kcal
  /// stat, which has no swatch.
  Widget _previewStat({
    required Widget valueWidget,
    MacroKind? kind,
    String? label,
  }) {
    assert(
      kind != null || label != null,
      'either kind or label must be provided',
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        valueWidget,
        if (kind != null)
          MacroLabel(kind: kind, variant: MacroLabelVariant.caption)
        else
          Text(
            label!.toUpperCase(),
            style: LiftText.labelSmall.copyWith(color: LiftColors.textDim),
          ),
      ],
    );
  }

  Widget _buildKeypadDock(Meal meal) {
    // No border here — LogNumericKeypad already paints its own top-only
    // seam; drawing a second one here doubled the hairline.
    return Container(
      decoration: const BoxDecoration(color: LiftColors.background),
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
