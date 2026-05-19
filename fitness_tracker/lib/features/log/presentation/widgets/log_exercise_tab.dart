import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../library/application/exercise_bloc.dart';
import '../../../settings/presentation/settings_scope.dart';
import '../../application/workout_bloc.dart';
import 'exercise_picker_sheet.dart';
import 'intensity_slider_widget.dart';

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
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  StreamSubscription<WorkoutUiEffect>? _workoutEffectsSub;
  Timer? _logCooldownTimer;

  Exercise? _selectedExercise;
  late DateTime _selectedDate;
  int _selectedIntensity = MuscleStimulus.defaultIntensity;
  bool _logCooldownActive = false;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    _repsController.addListener(() => setState(() {}));
    _weightController.addListener(() => setState(() {}));

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
    _repsController.dispose();
    _weightController.dispose();
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
            final bool canLog =
                _selectedExercise != null &&
                _repsController.text.isNotEmpty &&
                _weightController.text.isNotEmpty &&
                !_logCooldownActive;

            final int todaySetCount = _computeTodaySetCount(workoutState);

            return Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildExerciseSelector(context, exercises),
                        const SizedBox(height: 24),
                        _buildRepsInput(),
                        const SizedBox(height: 20),
                        _buildWeightInput(weightUnit),
                        const SizedBox(height: 20),
                        IntensitySliderWidget(
                          intensity: _selectedIntensity,
                          onChanged: (int value) {
                            setState(() => _selectedIntensity = value);
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildDatePicker(context),
                        const SizedBox(height: 20),
                        _buildMuscleGroupInfo(),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: _StickyLogBar(
                    canLog: canLog,
                    isLoading: isLoading,
                    todaySetCount: todaySetCount,
                    onLog: () => _handleLogSet(weightUnit),
                  ),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildExerciseSelector(
    BuildContext context,
    List<Exercise> exercises,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.exercise,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _openExercisePicker(context, exercises),
          borderRadius: BorderRadius.circular(12),
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
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedExercise?.name ?? AppStrings.selectExercise,
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

  Widget _buildRepsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.reps,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _repsController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.repeat),
            suffixText: AppStrings.unitReps,
          ),
        ),
      ],
    );
  }

  Widget _buildWeightInput(WeightUnit weightUnit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.weight,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: '0.0',
            labelText: WeightUnitUtils.inputLabel(weightUnit),
            helperText: 'Stored internally in kg for future sync compatibility',
            prefixIcon: const Icon(Icons.fitness_center),
            suffixText: WeightUnitUtils.unitLabel(weightUnit),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.workoutDate,
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
              children: <Widget>[
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

  Widget _buildMuscleGroupInfo() {
    if (_selectedExercise == null) return const SizedBox.shrink();

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
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                color: AppTheme.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.setWillCountToward,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedExercise!.muscleGroups.map((String mg) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  MuscleGroups.getDisplayName(mg),
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
    if (selected != null) setState(() => _selectedExercise = selected);
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

  int _computeTodaySetCount(WorkoutState state) {
    if (state is! WorkoutLoaded) return 0;
    return state.weeklySets.where((WorkoutSet s) {
      return s.date.year == _selectedDate.year &&
          s.date.month == _selectedDate.month &&
          s.date.day == _selectedDate.day;
    }).length;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
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
      setState(() => _selectedDate = picked);
    }
  }

  void _handleLogSet(WeightUnit weightUnit) {
    if (_selectedExercise == null) return;

    final int? reps = int.tryParse(_repsController.text);
    final double? enteredWeight = double.tryParse(_weightController.text);

    if (reps == null || enteredWeight == null) return;

    final WorkoutSet workoutSet = WorkoutSet(
      id: _uuid.v4(),
      exerciseId: _selectedExercise!.id,
      reps: reps,
      weight: WeightUnitUtils.toStoredKilograms(enteredWeight, weightUnit),
      intensity: _selectedIntensity,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    context.read<WorkoutBloc>().add(AddWorkoutSetEvent(workoutSet));
  }
}

class _StickyLogBar extends StatelessWidget {
  const _StickyLogBar({
    required this.canLog,
    required this.isLoading,
    required this.todaySetCount,
    required this.onLog,
  });

  final bool canLog;
  final bool isLoading;
  final int todaySetCount;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: const Border(top: BorderSide(color: AppTheme.borderDark)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (canLog && !isLoading) ? onLog : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      AppStrings.logSetButton,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          if (todaySetCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Logged ×$todaySetCount today',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.successGreen),
              ),
            ),
        ],
      ),
    );
  }
}
