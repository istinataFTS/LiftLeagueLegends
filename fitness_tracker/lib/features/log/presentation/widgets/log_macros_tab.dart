import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../application/nutrition_log_bloc.dart';
import 'shared/log_action_bar.dart';
import 'shared/log_numeric_keypad.dart';
import 'shared/log_stepper_field.dart';
import 'shared/log_ui_colors.dart';
import 'shared/macro_composition_bar.dart';

/// Which macro the in-layout keypad is currently editing.
enum _MacroField { protein, carbs, fats }

class LogMacrosTab extends StatefulWidget {
  const LogMacrosTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.onLoggedSuccess,
  });

  final DateTime? initialDate;
  final bool showSuccessFeedback;
  final ValueChanged<DateTime>? onLoggedSuccess;

  @override
  State<LogMacrosTab> createState() => _LogMacrosTabState();
}

class _LogMacrosTabState extends State<LogMacrosTab> {
  static const num _macroStep = 5;
  static const int _maxIntegerDigits = 4;

  final Uuid _uuid = const Uuid();

  double _protein = 0;
  double _carbs = 0;
  double _fats = 0;
  late DateTime _selectedDate;
  bool _logCooldownActive = false;
  _MacroField? _editingField;
  Timer? _logCooldownTimer;

  StreamSubscription<NutritionLogUiEffect>? _nutritionEffectsSub;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    final NutritionLogBloc nutritionBloc = context.read<NutritionLogBloc>();

    // D7: One-shot load of the selected date so "Today so far" can populate
    // when the standalone Log page opens this tab first. Guard against double
    // load — if the bloc already holds this date, skip.
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

        // Retain entered macros — short cooldown prevents accidental double-log.
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
        final bool canLog =
            (_protein > 0 || _carbs > 0 || _fats > 0) && !_logCooldownActive;

        return Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildInfoLine(context),
                    const SizedBox(height: 16),
                    _buildMacroRow(
                      label: AppStrings.protein,
                      value: _protein,
                      color: LogUiColors.protein,
                      onChanged: (num v) =>
                          setState(() => _protein = v.toDouble()),
                      onTapValue: () =>
                          setState(() => _editingField = _MacroField.protein),
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      label: AppStrings.carbs,
                      value: _carbs,
                      color: LogUiColors.carbs,
                      onChanged: (num v) =>
                          setState(() => _carbs = v.toDouble()),
                      onTapValue: () =>
                          setState(() => _editingField = _MacroField.carbs),
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      label: AppStrings.fats,
                      value: _fats,
                      color: LogUiColors.fats,
                      onChanged: (num v) =>
                          setState(() => _fats = v.toDouble()),
                      onTapValue: () =>
                          setState(() => _editingField = _MacroField.fats),
                    ),
                    const SizedBox(height: 20),
                    _buildTodaySoFar(nutritionState),
                  ],
                ),
              ),
            ),
            _editingField != null
                ? _buildKeypadDock(_editingField!)
                : _buildDock(canLog: canLog, isLoading: isLoading),
          ],
        );
      },
    );
  }

  // ─── Info line (spec §5.3) ────────────────────────────────────────────────

  Widget _buildInfoLine(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.info_outline, color: AppTheme.textDim, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No meal in your library? Enter macros directly.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
          ),
        ),
      ],
    );
  }

  // ─── Macro row (dot + name + stepper) (spec §5.4) ─────────────────────────

  Widget _buildMacroRow({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<num> onChanged,
    required VoidCallback onTapValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LogStepperField(
            key: Key('macrosStepper-$label'),
            label: 'grams',
            value: value,
            step: _macroStep,
            allowDecimal: true,
            accentColor: color,
            onChanged: onChanged,
            onTapValue: onTapValue,
          ),
        ),
      ],
    );
  }

  // ─── Today so far (spec §5.5) ─────────────────────────────────────────────

  Widget _buildTodaySoFar(NutritionLogState state) {
    if (state is! DailyLogsLoaded) return const SizedBox.shrink();
    if (!WeekDateUtils.isSameDay(state.date, _selectedDate)) {
      return const SizedBox.shrink();
    }

    final DateTime today = DateTime.now();
    final bool isToday = WeekDateUtils.isSameDay(_selectedDate, today);
    final String header = isToday
        ? 'Today so far'
        : '${DateFormat('MMM d').format(_selectedDate)} so far';

    final int totalCalories = state.totalCalories.round();
    final int totalProtein = state.totalProtein.round();
    final int totalCarbs = state.totalCarbs.round();
    final int totalFats = state.totalFats.round();
    final int logCount = state.logs.length;
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
              _todayCell(
                label: AppStrings.protein,
                grams: totalProtein,
                color: LogUiColors.protein,
              ),
              _todayCell(
                label: AppStrings.carbs,
                grams: totalCarbs,
                color: LogUiColors.carbs,
              ),
              _todayCell(
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
                : '${DateFormat('MMM d').format(_selectedDate)} macro composition',
            child: MacroCompositionBar(
              proteinGrams: state.totalProtein,
              carbsGrams: state.totalCarbs,
              fatsGrams: state.totalFats,
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCell({
    required String label,
    required int grams,
    required Color color,
  }) {
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

  // ─── Dock (normal + keypad) ───────────────────────────────────────────────

  Widget _buildDock({required bool canLog, required bool isLoading}) {
    return LogActionBar(
      ctaLabel: AppStrings.logMacrosButton,
      ctaIcon: Icons.local_fire_department,
      canSubmit: canLog,
      isLoading: isLoading,
      onSubmit: _handleLogMacros,
      previewSlot: _buildDockPreview(),
    );
  }

  Widget _buildDockPreview() {
    final double calories = MacroCalculator.calculateCalories(
      protein: _protein,
      carbs: _carbs,
      fat: _fats,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.local_fire_department,
              color: AppTheme.primaryOrangeLight,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              '${calories.round()}',
              style: const TextStyle(
                color: AppTheme.primaryOrangeLight,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(
                'kcal this entry',
                style: TextStyle(color: AppTheme.textDim, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'This entry macro composition',
          child: MacroCompositionBar(
            proteinGrams: _protein,
            carbsGrams: _carbs,
            fatsGrams: _fats,
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadDock(_MacroField field) {
    final double seed = switch (field) {
      _MacroField.protein => _protein,
      _MacroField.carbs => _carbs,
      _MacroField.fats => _fats,
    };
    final String label = switch (field) {
      _MacroField.protein => 'protein',
      _MacroField.carbs => 'carbs',
      _MacroField.fats => 'fats',
    };

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
          initialValue: seed,
          label: label,
          unitSuffix: 'g',
          allowDecimal: true,
          maxIntegerDigits: _maxIntegerDigits,
          onSubmit: (num value) => setState(() {
            final double v = value.toDouble();
            switch (field) {
              case _MacroField.protein:
                _protein = v;
                break;
              case _MacroField.carbs:
                _carbs = v;
                break;
              case _MacroField.fats:
                _fats = v;
                break;
            }
            _editingField = null;
          }),
          onCancel: () => setState(() => _editingField = null),
        ),
      ),
    );
  }

  // ─── Log handler ──────────────────────────────────────────────────────────

  void _handleLogMacros() {
    final double calories = MacroCalculator.calculateCalories(
      protein: _protein,
      carbs: _carbs,
      fat: _fats,
    );

    final NutritionLog nutritionLog = NutritionLog(
      id: _uuid.v4(),
      mealId: null,
      mealName: 'Direct Macro Entry',
      gramsConsumed: null,
      proteinGrams: _protein,
      carbsGrams: _carbs,
      fatGrams: _fats,
      calories: calories,
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
