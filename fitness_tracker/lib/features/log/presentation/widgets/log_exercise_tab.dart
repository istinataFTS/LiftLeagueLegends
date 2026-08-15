import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/lift_theme.dart';
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
import 'shared/log_numeric_keypad.dart';
import 'shared/log_stepper_field.dart';

/// Which stepper value is currently being edited via the in-layout keypad.
enum _KeypadField { reps, weight }

class LogExerciseTab extends StatefulWidget {
  const LogExerciseTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.onLoggedSuccess,
  });

  final DateTime? initialDate;
  final bool showSuccessFeedback;
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
                  ? LiftColors.warning
                  : LiftColors.success,
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

  void _setKeypad(_KeypadField? field) {
    setState(() => _activeKeypad = field);
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
              backgroundColor: LiftColors.error,
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
                child: CircularProgressIndicator(color: LiftColors.actionTint),
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
            final List<WorkoutSet> selectedDateSets = _setsForSelectedDate(
              workoutState,
            );
            final int selectedDateSetCount = selectedDateSets.length;
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
                        _buildExerciseHeader(
                          context,
                          exercises,
                          insight,
                          selectedDateSetCount,
                          weightUnit,
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: LiftColors.rule),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: LogStepperField(
                                key: const Key('exerciseRepsStepper'),
                                label: AppStrings.reps,
                                value: _reps,
                                onChanged: (num v) =>
                                    setState(() => _reps = v.round()),
                                onTapValue: () => _setKeypad(_KeypadField.reps),
                              ),
                            ),
                            Container(
                              width: LiftShape.borderWidth,
                              height: 64,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: LiftColors.hairline,
                            ),
                            Expanded(
                              child: LogStepperField(
                                key: const Key('exerciseWeightStepper'),
                                label: WeightUnitUtils.inputLabel(weightUnit),
                                value: _weight,
                                step: 2.5,
                                allowDecimal: true,
                                onChanged: (num v) =>
                                    setState(() => _weight = v.toDouble()),
                                onTapValue: () =>
                                    _setKeypad(_KeypadField.weight),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: LiftColors.rule),
                        const SizedBox(height: 16),
                        LogIntensitySelector(
                          intensity: _selectedIntensity,
                          onChanged: (int value) =>
                              setState(() => _selectedIntensity = value),
                        ),
                        const SizedBox(height: 20),
                        _buildSelectedDateFeed(
                          context,
                          selectedDateSets,
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
                        statusLine: selectedDateSetCount > 0
                            ? Text(
                                'Logged ×$selectedDateSetCount $_dateSuffixLabel'
                                    .toUpperCase(),
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

  bool get _selectedIsToday =>
      WeekDateUtils.isSameDay(_selectedDate, DateTime.now());

  /// `today` when the selected date is today, otherwise `MMM d` — mirrors the
  /// Macros tab's date-guarded labelling so the feed/count never claim "today"
  /// for a past date (e.g. when logging through the History sheet).
  String get _dateSuffixLabel =>
      _selectedIsToday ? 'today' : DateFormat('MMM d').format(_selectedDate);

  /// The section label above the set feed (spec §5.2): `SETS TODAY` when the
  /// selected date is today, otherwise date-scoped so it never lies about
  /// "today" for a past date.
  String get _setsFeedLabel => _selectedIsToday
      ? 'SETS TODAY'
      : 'SETS ${DateFormat('MMM d').format(_selectedDate).toUpperCase()}';

  /// The insight only applies when it matches the currently-selected exercise
  /// (a stale insight for a previous selection must not paint this card).
  /// PR + fatigue read "current" data and are intentionally not date-scoped.
  ExerciseInsight? _insightFor(WorkoutState state) {
    if (state is! WorkoutLoaded) return null;
    final ExerciseInsight? insight = state.selectedInsight;
    if (insight == null || _selectedExercise == null) return null;
    return insight.exerciseId == _selectedExercise!.id ? insight : null;
  }

  List<WorkoutSet> _setsForSelectedDate(WorkoutState state) {
    if (state is! WorkoutLoaded || _selectedExercise == null) {
      return const <WorkoutSet>[];
    }
    return state.weeklySets
        .where(
          (WorkoutSet s) =>
              s.exerciseId == _selectedExercise!.id &&
              WeekDateUtils.isSameDay(s.date, _selectedDate),
        )
        .toList()
      ..sort(
        (WorkoutSet a, WorkoutSet b) => a.createdAt.compareTo(b.createdAt),
      );
  }

  Widget _buildExerciseHeader(
    BuildContext context,
    List<Exercise> exercises,
    ExerciseInsight? insight,
    int setCount,
    WeightUnit weightUnit,
  ) {
    final Exercise? exercise = _selectedExercise;
    final WorkoutSet? pr = insight?.personalRecord;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.exercise.toUpperCase(),
          style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openExercisePicker(context, exercises),
          child: SizedBox(
            height: 44,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    exercise?.name ?? AppStrings.selectExercise,
                    style: LiftText.headlineMedium.copyWith(
                      color: exercise == null
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
        if (exercise != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (pr != null) ...<Widget>[
                _PrBadge(
                  label: WeightUnitUtils.formatForDisplay(
                    pr.weight,
                    weightUnit,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                '$setCount sets $_dateSuffixLabel',
                style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
              ),
            ],
          ),
        ],
        if (exercise != null &&
            insight != null &&
            insight.muscles.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ExerciseFatigueChips(muscles: insight.muscles),
        ],
      ],
    );
  }

  Widget _buildSelectedDateFeed(
    BuildContext context,
    List<WorkoutSet> sets,
    WeightUnit weightUnit,
  ) {
    final Exercise? exercise = _selectedExercise;
    if (exercise == null) return const SizedBox.shrink();

    final double volumeKg = sets.fold<double>(
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
                _setsFeedLabel,
                style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${volumeText.toUpperCase()} TOTAL',
              style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _selectedIsToday
                  ? 'No sets yet today'
                  : 'No sets on ${DateFormat('MMM d').format(_selectedDate)}',
              style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
            ),
          )
        else
          for (int i = 0; i < sets.length; i++)
            ExerciseSetRow(
              setNumber: i + 1,
              intensity: sets[i].intensity,
              weightText: WeightUnitUtils.formatForDisplay(
                sets[i].weight,
                weightUnit,
              ),
              reps: sets[i].reps,
            ),
      ],
    );
  }

  Widget _buildKeypadDock(WeightUnit weightUnit) {
    final _KeypadField field = _activeKeypad!;
    final bool isWeight = field == _KeypadField.weight;

    return Container(
      decoration: const BoxDecoration(
        color: LiftColors.background,
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LogNumericKeypad(
          initialValue: isWeight ? _weight : _reps,
          label: isWeight ? AppStrings.weight.toLowerCase() : 'reps',
          unitSuffix: isWeight ? WeightUnitUtils.unitLabel(weightUnit) : '',
          allowDecimal: isWeight,
          maxIntegerDigits: isWeight ? 4 : 3,
          onSubmit: (num value) {
            setState(() {
              if (isWeight) {
                _weight = value.toDouble();
              } else {
                _reps = value.round();
              }
            });
            _setKeypad(null);
          },
          onCancel: () => _setKeypad(null),
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
            const Icon(Icons.error_outline, size: 64, color: LiftColors.error),
            const SizedBox(height: 16),
            Text(
              AppStrings.errorLoadingExercises,
              style: LiftText.titleLarge.copyWith(
                color: LiftColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: LiftText.bodySmall.copyWith(color: LiftColors.textDim),
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
              color: LiftColors.textDim,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noExercisesAvailable,
              style: LiftText.titleMedium.copyWith(
                color: LiftColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.createExercisesFirst,
              style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
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

/// `PR` is the one surviving badge exception (design spec §5.2): square,
/// filled `actionFill`, no icon — every other pill/badge in the Log tabs is
/// gone.
class _PrBadge extends StatelessWidget {
  const _PrBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: LiftColors.actionFill,
      child: Text(
        'PR $label',
        style: LiftText.labelLarge.copyWith(color: Colors.white),
      ),
    );
  }
}
