import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/bloc_effects_mixin.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/muscle_visual_data.dart';
import '../../../../domain/entities/time_period.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import '../../../../domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';
import '../../../../domain/usecases/workout_sets/add_workout_set.dart';
import '../../../../domain/usecases/workout_sets/get_exercise_personal_record.dart';
import '../../../../domain/usecases/workout_sets/get_weekly_sets.dart';
import 'exercise_insight.dart';

abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();

  @override
  List<Object?> get props => [];
}

class AddWorkoutSetEvent extends WorkoutEvent {
  final WorkoutSet workoutSet;

  const AddWorkoutSetEvent(this.workoutSet);

  @override
  List<Object?> get props => [workoutSet];
}

class LoadWeeklySetsEvent extends WorkoutEvent {
  const LoadWeeklySetsEvent();
}

class RefreshWeeklySetsEvent extends WorkoutEvent {
  const RefreshWeeklySetsEvent();
}

class SelectExerciseForInsightEvent extends WorkoutEvent {
  final Exercise exercise;

  const SelectExerciseForInsightEvent(this.exercise);

  @override
  List<Object?> get props => [exercise];
}

class ClearExerciseInsightEvent extends WorkoutEvent {
  const ClearExerciseInsightEvent();
}

abstract class WorkoutState extends Equatable {
  const WorkoutState();

  @override
  List<Object?> get props => [];
}

class WorkoutInitial extends WorkoutState {}

class WorkoutLoading extends WorkoutState {}

class WorkoutLoaded extends WorkoutState {
  final List<WorkoutSet> weeklySets;
  final ExerciseInsight? selectedInsight;

  const WorkoutLoaded(this.weeklySets, {this.selectedInsight});

  @override
  List<Object?> get props => [weeklySets, selectedInsight];
}

class WorkoutError extends WorkoutState {
  final String message;

  const WorkoutError(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class WorkoutUiEffect {
  const WorkoutUiEffect();
}

/// Emitted alongside [WorkoutError] state when [AddWorkoutSetEvent] fails.
/// [VoiceCommandRouter] listens for this to complete the in-flight mutation
/// completer with a failure outcome so [VoiceBloc] can speak an error reply.
class WorkoutMutationFailedEffect extends WorkoutUiEffect {
  const WorkoutMutationFailedEffect(this.message);

  final String message;
}

class WorkoutLoggedEffect extends WorkoutUiEffect {
  final String message;
  final List<String> affectedMuscles;

  /// True when the set was persisted but no muscle-group mapping could be
  /// applied (e.g. the exercise has no muscle factors seeded).  The UI
  /// should surface this as a non-fatal warning so users know why the
  /// body map did not light up for this set.
  final bool hadNoMuscleMapping;

  const WorkoutLoggedEffect({
    required this.message,
    required this.affectedMuscles,
    this.hadNoMuscleMapping = false,
  });
}

class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState>
    with BlocEffectsMixin<WorkoutState, WorkoutUiEffect> {
  final AddWorkoutSet addWorkoutSet;
  final GetWeeklySets getWeeklySets;
  final CalculateMuscleStimulus calculateMuscleStimulus;
  final GetMuscleVisualData getMuscleVisualData;
  final GetExercisePersonalRecord getExercisePersonalRecord;

  List<WorkoutSet> _cachedWeeklySets = [];
  Exercise? _selectedExercise;

  WorkoutBloc({
    required this.addWorkoutSet,
    required this.getWeeklySets,
    required this.calculateMuscleStimulus,
    required this.getMuscleVisualData,
    required this.getExercisePersonalRecord,
  }) : super(WorkoutInitial()) {
    on<AddWorkoutSetEvent>(_onAddWorkoutSet);
    on<LoadWeeklySetsEvent>(_onLoadWeeklySets);
    on<RefreshWeeklySetsEvent>(_onRefreshWeeklySets);
    on<SelectExerciseForInsightEvent>(_onSelectExerciseForInsight);
    on<ClearExerciseInsightEvent>(_onClearExerciseInsight);
  }

  Future<void> _onAddWorkoutSet(
    AddWorkoutSetEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(WorkoutLoading());

    // addWorkoutSet saves the set and runs a full muscle-stimulus rebuild so
    // that every date's rolling weekly load (including today's) reflects the
    // newly-logged set, regardless of which date it was logged to.
    final addResult = await addWorkoutSet(event.workoutSet);

    await addResult.fold(
      (failure) async {
        emit(WorkoutError(failure.message));
        emitEffect(WorkoutMutationFailedEffect(failure.message));
      },
      (_) async {
        // Derive which muscles the exercise targets for the UI notification.
        // The actual stimulus update is handled by the rebuild inside
        // AddWorkoutSet, so no separate DB write is needed here.
        final stimulusResult = await calculateMuscleStimulus.calculateForSet(
          exerciseId: event.workoutSet.exerciseId,
          sets: 1,
          intensity: event.workoutSet.intensity,
        );

        final affectedMuscles = stimulusResult.fold((failure) {
          AppLogger.warning(
            'calculateMuscleStimulus failed: ${failure.message}',
            category: 'workout',
          );
          return <String>[];
        }, (muscleStimuli) => muscleStimuli.keys.toList());

        final hadNoMuscleMapping = affectedMuscles.isEmpty;
        final message = hadNoMuscleMapping
            ? AppStrings.setLoggedNoMuscleMapping
            : AppStrings.setLogged;

        await _loadWeeklySetsData(emit);

        emitEffect(
          WorkoutLoggedEffect(
            message: message,
            affectedMuscles: affectedMuscles,
            hadNoMuscleMapping: hadNoMuscleMapping,
          ),
        );
      },
    );
  }

  Future<void> _onLoadWeeklySets(
    LoadWeeklySetsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    await _loadWeeklySetsData(emit, showLoading: true);
  }

  Future<void> _onRefreshWeeklySets(
    RefreshWeeklySetsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    await _loadWeeklySetsData(emit);
  }

  Future<void> _onSelectExerciseForInsight(
    SelectExerciseForInsightEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    _selectedExercise = event.exercise;
    final insight = await _computeInsight(event.exercise, _cachedWeeklySets);
    emit(WorkoutLoaded(_cachedWeeklySets, selectedInsight: insight));
  }

  Future<void> _onClearExerciseInsight(
    ClearExerciseInsightEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    _selectedExercise = null;
    emit(WorkoutLoaded(_cachedWeeklySets));
  }

  Future<void> _loadWeeklySetsData(
    Emitter<WorkoutState> emit, {
    bool showLoading = false,
  }) async {
    if (showLoading) {
      emit(WorkoutLoading());
    }

    final result = await getWeeklySets();

    await result.fold((failure) async => emit(WorkoutError(failure.message)), (
      sets,
    ) async {
      _cachedWeeklySets = sets;
      final selected = _selectedExercise;
      if (selected != null) {
        final insight = await _computeInsight(selected, sets);
        emit(WorkoutLoaded(sets, selectedInsight: insight));
      } else {
        emit(WorkoutLoaded(sets));
      }
    });
  }

  Future<ExerciseInsight> _computeInsight(
    Exercise exercise,
    List<WorkoutSet> weeklySets,
  ) async {
    final now = DateTime.now();
    int setsToday = 0;
    double volumeTodayKg = 0;
    for (final set in weeklySets) {
      if (set.exerciseId != exercise.id) continue;
      if (!_isSameDay(set.date, now)) continue;
      setsToday += 1;
      volumeTodayKg += set.weight * set.reps;
    }

    final prResult = await getExercisePersonalRecord(exercise.id);
    final WorkoutSet? personalRecord = prResult.fold((failure) {
      AppLogger.warning(
        'getExercisePersonalRecord failed: ${failure.message}',
        category: 'workout',
      );
      return null;
    }, (set) => set);

    final muscleResult = await getMuscleVisualData(TimePeriod.week);
    final Map<String, MuscleVisualData> visualByGranular = muscleResult.fold((
      failure,
    ) {
      AppLogger.warning(
        'getMuscleVisualData failed: ${failure.message}',
        category: 'workout',
      );
      return <String, MuscleVisualData>{};
    }, (map) => map);

    final List<MuscleFatigue> muscles = <MuscleFatigue>[];
    for (final coarse in exercise.muscleGroups) {
      MuscleVisualData? top;
      for (final entry in MuscleGroups.granularToSimple.entries) {
        if (entry.value != coarse) continue;
        final data = visualByGranular[entry.key];
        if (data == null) continue;
        if (top == null || data.visualIntensity > top.visualIntensity) {
          top = data;
        }
      }
      if (top == null) continue;
      muscles.add(
        MuscleFatigue(
          coarseGroup: coarse,
          displayName: MuscleGroups.getDisplayName(coarse),
          percent: (top.visualIntensity * 100).round().clamp(0, 100),
          bucket: top.bucket,
          color: top.color,
        ),
      );
    }

    return ExerciseInsight(
      exerciseId: exercise.id,
      personalRecord: personalRecord,
      setsToday: setsToday,
      volumeTodayKg: volumeTodayKg,
      muscles: muscles,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<WorkoutSet> get cachedWeeklySets => _cachedWeeklySets;
}
