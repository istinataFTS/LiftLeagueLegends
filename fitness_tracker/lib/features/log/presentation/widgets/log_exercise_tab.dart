import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../core/utils/week_date_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../library/application/exercise_bloc.dart';
import '../../../settings/presentation/settings_scope.dart';
import '../../application/exercise_insight.dart';
import '../../application/workout_bloc.dart';
import 'exercise_fatigue_chips.dart';
import 'exercise_picker_sheet.dart';
import 'exercise_set_row.dart';
import 'log_intensity_selector.dart';
import 'shared/log_action_bar.dart';
import 'shared/log_date_pill.dart';
import 'shared/log_numeric_keypad.dart';
import 'shared/log_stepper_field.dart';
import 'shared/log_ui_colors.dart';

/// Which stepper value is currently being edited via the in-layout keypad.
enum _KeypadField { reps, weight }

class LogExerciseTab extends StatefulWidget {
  const LogExerciseTab({
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
  State<LogExerciseTab> createState() => _LogExerciseTabState();
}

class _LogExerciseTabState extends State<LogExerciseTab> {
  final Uuid _uuid = const Uuid();

  StreamSubscription<WorkoutUiEffect>? _workoutEffectsSub;
  Timer? _logCooldownTimer;

  Exercise? _selectedExercise;
  late DateTime _selectedDate;
  int _reps = 0;
  double _weight = 0;
  int _selectedIntensity = MuscleStimulus.defaultIntensity;
  bool _logCooldownActive = false;
  _KeypadField? _activeKeypad;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    final WorkoutBloc workoutBloc = context.read<WorkoutBloc>();
    _workoutEffectsSub = workoutBloc.effects.listen((WorkoutUiEffect effect) {
      if (!mounted) return;

      if (effect is WorkoutLoggedEffect) {
        if (widget.showSuccessFeedback) {
          final bool isWarning = effect.hadNoMuscleMapping;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    effect.message,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (effect.affectedMuscles.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Training: ${effect.affectedMuscles.map((m) => MuscleGroups.getDisplayName(m)).join(", ")}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
              backgroundColor: isWarning
                  ? AppTheme.warningAmber
                  : AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
              duration: Duration(seconds: isWarning ? 4 : 2),
            ),
          );
        }

        widget.onLoggedSuccess?.call(_selectedDate);

        // Retain form values — start a short cooldown to prevent accidental
        // double-taps while the bloc processes the previous set.
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
    _workoutEffectsSub?.cancel();
    _logCooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WeightUnit weightUnit = SettingsScope.weightUnitOf(context);

    return BlocConsumer<WorkoutBloc, WorkoutState>(
      listener: (BuildContext context, WorkoutState state) {
        if (state is WorkoutError) {
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
      builder: (BuildContext context, WorkoutState workoutState) {
        return BlocBuilder<ExerciseBloc, ExerciseState>(
          builder: (BuildContext context, ExerciseState exerciseState) {
            if (exerciseState is ExerciseInitial ||
                exerciseState is ExerciseLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryOrange),
              );
            }

            if (exerciseState is ExerciseError) {
              return _buildErrorState(context, exerciseState.message);
            }

            final List<Exercise> exercises = exerciseState is ExercisesLoaded
                ? exerciseState.exercises
                : <Exercise>[];

            if (exercises.isEmpty) {
              return _buildEmptyExercisesState(context);
            }

            final bool isLoading = workoutState is WorkoutLoading;
            final ExerciseInsight? insight = _insightFor(workoutState);
            final List<WorkoutSet> todaySets = _todaySetsFor(workoutState);
            final int todaySetCount = insight?.setsToday ?? todaySets.length;
            final bool canLog =
                _selectedExercise != null &&
                _reps > 0 &&
                _weight > 0 &&
                !_logCooldownActive;

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
                        _buildExerciseCard(
                          context,
                          exercises,
                          insight,
                          weightUnit,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: LogStepperField(
                                label: AppStrings.reps,
                                value: _reps,
                                onChanged: (num v) =>
                                    setState(() => _reps = v.round()),
                                onTapValue: () => setState(
                                  () => _activeKeypad = _KeypadField.reps,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LogStepperField(
                                label: WeightUnitUtils.inputLabel(weightUnit),
                                value: _weight,
                                step: 2.5,
                                allowDecimal: true,
                                unitSuffix: WeightUnitUtils.unitLabel(
                                  weightUnit,
                                ),
                                onChanged: (num v) =>
                                    setState(() => _weight = v.toDouble()),
                                onTapValue: () => setState(
                                  () => _activeKeypad = _KeypadField.weight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LogIntensitySelector(
                          intensity: _selectedIntensity,
                          onChanged: (int value) =>
                              setState(() => _selectedIntensity = value),
                        ),
                        const SizedBox(height: 20),
                        _buildTodayFeed(
                          context,
                          todaySets,
                          insight,
                          weightUnit,
                        ),
                      ],
                    ),
                  ),
                ),
                _activeKeypad != null
                    ? _buildKeypadDock(weightUnit)
                    : LogActionBar(
                        ctaLabel: AppStrings.logSetButton,
                        ctaIcon: Icons.add_circle_outline,
                        canSubmit: canLog,
                        isLoading: isLoading,
                        onSubmit: () => _handleLogSet(weightUnit),
                        statusLine: todaySetCount > 0
                            ? Text(
                                'Logged ×$todaySetCount today',
                                style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : null,
                      ),
              ],
            );
          },
        );
      },
    );
  }

  /// The insight only applies when it matches the currently-selected exercise
  /// (a stale insight for a previous selection must not paint this card).
  ExerciseInsight? _insightFor(WorkoutState state) {
    if (state is! WorkoutLoaded) return null;
    final ExerciseInsight? insight = state.selectedInsight;
    if (insight == null || _selectedExercise == null) return null;
    return insight.exerciseId == _selectedExercise!.id ? insight : null;
  }

  List<WorkoutSet> _todaySetsFor(WorkoutState state) {
    if (state is! WorkoutLoaded || _selectedExercise == null) {
      return const <WorkoutSet>[];
    }
    final DateTime now = DateTime.now();
    return state.weeklySets
        .where(
          (WorkoutSet s) =>
              s.exerciseId == _selectedExercise!.id &&
              WeekDateUtils.isSameDay(s.date, now),
        )
        .toList()
      ..sort(
        (WorkoutSet a, WorkoutSet b) => a.createdAt.compareTo(b.createdAt),
      );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    List<Exercise> exercises,
    ExerciseInsight? insight,
    WeightUnit weightUnit,
  ) {
    final Exercise? exercise = _selectedExercise;
    final WorkoutSet? pr = insight?.personalRecord;
    final int setsToday = insight?.setsToday ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () => _openExercisePicker(context, exercises),
            borderRadius: BorderRadius.circular(8),
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
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        exercise?.name ?? AppStrings.selectExercise,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (exercise != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            if (pr != null) ...<Widget>[
                              _PrBadge(
                                label: WeightUnitUtils.formatForDisplay(
                                  pr.weight,
                                  weightUnit,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '$setsToday sets today',
                              style: const TextStyle(
                                color: AppTheme.textDim,
                                fontSize: 12,
                                fontFeatures: <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.expand_more, color: AppTheme.textDim),
              ],
            ),
          ),
          if (exercise != null &&
              insight != null &&
              insight.muscles.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderDark),
            const SizedBox(height: 12),
            ExerciseFatigueChips(muscles: insight.muscles),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayFeed(
    BuildContext context,
    List<WorkoutSet> todaySets,
    ExerciseInsight? insight,
    WeightUnit weightUnit,
  ) {
    final Exercise? exercise = _selectedExercise;
    if (exercise == null) return const SizedBox.shrink();

    final double volumeKg =
        insight?.volumeTodayKg ??
        todaySets.fold<double>(
          0,
          (double sum, WorkoutSet s) => sum + s.weight * s.reps,
        );
    final String volumeText = WeightUnitUtils.formatForDisplay(
      volumeKg,
      weightUnit,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${exercise.name} · today',
                style: const TextStyle(
                  color: AppTheme.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$volumeText total',
              style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 13,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (todaySets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No sets yet today',
              style: TextStyle(color: AppTheme.textDim, fontSize: 13),
            ),
          )
        else
          for (int i = 0; i < todaySets.length; i++)
            ExerciseSetRow(
              setNumber: i + 1,
              intensity: todaySets[i].intensity,
              weightText: WeightUnitUtils.formatForDisplay(
                todaySets[i].weight,
                weightUnit,
              ),
              reps: todaySets[i].reps,
            ),
      ],
    );
  }

  Widget _buildKeypadDock(WeightUnit weightUnit) {
    final _KeypadField field = _activeKeypad!;
    final bool isWeight = field == _KeypadField.weight;

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
          initialValue: isWeight ? _weight : _reps,
          label: isWeight ? AppStrings.weight.toLowerCase() : 'reps',
          unitSuffix: isWeight ? WeightUnitUtils.unitLabel(weightUnit) : '',
          allowDecimal: isWeight,
          maxIntegerDigits: isWeight ? 4 : 3,
          onSubmit: (num value) => setState(() {
            if (isWeight) {
              _weight = value.toDouble();
            } else {
              _reps = value.round();
            }
            _activeKeypad = null;
          }),
          onCancel: () => setState(() => _activeKeypad = null),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              AppStrings.errorLoadingExercises,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.read<ExerciseBloc>().add(LoadExercisesEvent()),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExercisesState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: AppTheme.textDim,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noExercisesAvailable,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.createExercisesFirst,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExercisePicker(
    BuildContext context,
    List<Exercise> exercises,
  ) async {
    final List<String> recentIds = _buildRecentExerciseIds(
      context.read<WorkoutBloc>().state,
    );

    final Exercise? selected = await ExercisePickerSheet.show(
      context,
      exercises: exercises,
      recentExerciseIds: recentIds,
      selected: _selectedExercise,
    );

    if (!mounted) return;
    if (selected != null) {
      setState(() => _selectedExercise = selected);
      context.read<WorkoutBloc>().add(SelectExerciseForInsightEvent(selected));
    }
  }

  List<String> _buildRecentExerciseIds(WorkoutState state) {
    if (state is! WorkoutLoaded) return const [];

    final List<WorkoutSet> sorted = List<WorkoutSet>.from(state.weeklySets)
      ..sort((WorkoutSet a, WorkoutSet b) {
        final int dateCmp = b.date.compareTo(a.date);
        return dateCmp != 0 ? dateCmp : b.createdAt.compareTo(a.createdAt);
      });

    final Set<String> seen = {};
    return sorted
        .map((WorkoutSet s) => s.exerciseId)
        .where(seen.add)
        .take(5)
        .toList();
  }

  void _handleLogSet(WeightUnit weightUnit) {
    if (_selectedExercise == null) return;
    if (_reps <= 0 || _weight <= 0) return;

    final WorkoutSet workoutSet = WorkoutSet(
      id: _uuid.v4(),
      exerciseId: _selectedExercise!.id,
      reps: _reps,
      weight: WeightUnitUtils.toStoredKilograms(_weight, weightUnit),
      intensity: _selectedIntensity,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    context.read<WorkoutBloc>().add(AddWorkoutSetEvent(workoutSet));
  }
}

class _PrBadge extends StatelessWidget {
  const _PrBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LogUiColors.fats.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.emoji_events, size: 13, color: LogUiColors.fats),
          const SizedBox(width: 4),
          Text(
            'PR $label',
            style: const TextStyle(
              color: LogUiColors.fats,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
