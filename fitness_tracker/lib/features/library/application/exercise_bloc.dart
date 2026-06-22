import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/usecases/exercises/add_exercise.dart';
import '../../../domain/usecases/exercises/delete_exercise.dart';
import '../../../domain/usecases/exercises/ensure_default_exercises.dart';
import '../../../domain/usecases/exercises/get_all_exercises.dart';
import '../../../domain/usecases/exercises/get_exercise_by_id.dart';
import '../../../domain/usecases/exercises/get_exercises_for_muscle.dart';
import '../../../domain/usecases/exercises/update_exercise.dart';
import '../../../domain/usecases/muscle_factors/get_muscle_factors_for_exercise.dart';
import '../../voice/data/lookup/exercise_lookup.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class ExerciseEvent extends Equatable {
  const ExerciseEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class LoadExercisesEvent extends ExerciseEvent {}

class LoadExerciseByIdEvent extends ExerciseEvent {
  const LoadExerciseByIdEvent(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}

class LoadExercisesForMuscleEvent extends ExerciseEvent {
  const LoadExercisesForMuscleEvent(this.muscleGroup);

  final String muscleGroup;

  @override
  List<Object?> get props => <Object?>[muscleGroup];
}

/// Dispatched by the exercise dialog when opened for editing.
/// The bloc responds with [ExerciseFactorsLoaded] so the dialog can populate
/// its per-muscle factor sliders with the previously saved weights.
class LoadExerciseFactorsEvent extends ExerciseEvent {
  const LoadExerciseFactorsEvent(this.exerciseId);

  final String exerciseId;

  @override
  List<Object?> get props => <Object?>[exerciseId];
}

class AddExerciseEvent extends ExerciseEvent {
  const AddExerciseEvent(this.exercise, {this.muscleFactors});

  final Exercise exercise;

  /// Optional per-muscle factor map (simple-key → factor ∈ [0,1]).
  /// When provided, the factors are persisted alongside the exercise.
  /// When null, every selected muscle receives factor 1.0 (default behaviour).
  final Map<String, double>? muscleFactors;

  @override
  List<Object?> get props => <Object?>[exercise, muscleFactors];
}

class UpdateExerciseEvent extends ExerciseEvent {
  const UpdateExerciseEvent(this.exercise, {this.muscleFactors});

  final Exercise exercise;

  /// Optional per-muscle factor map (simple-key → factor ∈ [0,1]).
  /// When provided, the factors are persisted alongside the exercise.
  /// When null, every selected muscle receives factor 1.0 (default behaviour).
  final Map<String, double>? muscleFactors;

  @override
  List<Object?> get props => <Object?>[exercise, muscleFactors];
}

class DeleteExerciseEvent extends ExerciseEvent {
  const DeleteExerciseEvent(this.id);

  final String id;

  @override
  List<Object?> get props => <Object?>[id];
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

abstract class ExerciseState extends Equatable {
  const ExerciseState();

  @override
  List<Object?> get props => <Object?>[];
}

class ExerciseInitial extends ExerciseState {}

class ExerciseLoading extends ExerciseState {}

class ExercisesLoaded extends ExerciseState {
  const ExercisesLoaded(this.exercises);

  final List<Exercise> exercises;

  @override
  List<Object?> get props => <Object?>[exercises];
}

class ExerciseLoaded extends ExerciseState {
  const ExerciseLoaded(this.exercise);

  final Exercise exercise;

  @override
  List<Object?> get props => <Object?>[exercise];
}

/// Emitted in response to [LoadExerciseFactorsEvent].
///
/// Intentionally a separate state from [ExercisesLoaded] so the exercises list
/// can remain visible while the dialog populates its sliders.  The exercises
/// tab caches the last-loaded exercise list and uses it as a fallback when
/// this state is active.
class ExerciseFactorsLoaded extends ExerciseState {
  const ExerciseFactorsLoaded({
    required this.exerciseId,
    required this.factors,
  });

  final String exerciseId;

  /// Muscle-group key → factor value as stored in the database.
  /// Keys may be granular (seed data) or simple (user-created exercises).
  final Map<String, double> factors;

  @override
  List<Object?> get props => <Object?>[exerciseId, factors];
}

class ExerciseError extends ExerciseState {
  const ExerciseError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

class ExerciseOperationSuccess extends ExerciseState {
  const ExerciseOperationSuccess(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {
  ExerciseBloc({
    required this.getAllExercises,
    required this.getExerciseById,
    required this.getExercisesForMuscle,
    required this.addExercise,
    required this.updateExercise,
    required this.deleteExercise,
    required this.ensureDefaultExercises,
    required this.getMuscleFactorsForExercise,
    required this.exerciseLookup,
  }) : super(ExerciseInitial()) {
    on<LoadExercisesEvent>(_onLoadExercises);
    on<LoadExerciseByIdEvent>(_onLoadExerciseById);
    on<LoadExercisesForMuscleEvent>(_onLoadExercisesForMuscle);
    on<LoadExerciseFactorsEvent>(_onLoadExerciseFactors);
    on<AddExerciseEvent>(_onAddExercise);
    on<UpdateExerciseEvent>(_onUpdateExercise);
    on<DeleteExerciseEvent>(_onDeleteExercise);
  }

  final GetAllExercises getAllExercises;
  final GetExerciseById getExerciseById;
  final GetExercisesForMuscle getExercisesForMuscle;
  final AddExercise addExercise;
  final UpdateExercise updateExercise;
  final DeleteExercise deleteExercise;
  final EnsureDefaultExercises ensureDefaultExercises;
  final GetMuscleFactorsForExercise getMuscleFactorsForExercise;
  final ExerciseLookup exerciseLookup;

  /// Guards against running the default-exercise seeding more than once per
  /// bloc instance (= per user session, since [AuthSessionShell] recreates
  /// the bloc on every user switch).
  bool _hasEnsuredDefaults = false;

  Future<void> _onLoadExercises(
    LoadExercisesEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    emit(ExerciseLoading());
    final result = await getAllExercises();

    await result.fold(
      (failure) async {
        _logFailure('LoadExercisesEvent', failure);
        emit(ExerciseError(failure.message));
      },
      (exercises) async {
        // If the user has no exercises and we haven't seeded yet this session,
        // run the per-user default-exercise seeding as a safety-net fallback
        // (e.g. fresh device, second user on a shared device, cloud account
        // with no exercises). The flag prevents an infinite re-seed loop.
        if (exercises.isEmpty && !_hasEnsuredDefaults) {
          AppLogger.info(
            'LoadExercisesEvent: empty result — running default-exercise '
            'reseed (first time this session)',
            category: 'exercise_bloc',
          );
          _hasEnsuredDefaults = true;
          await ensureDefaultExercises();

          // Reload after seeding so the UI shows the freshly inserted exercises.
          final reloadResult = await getAllExercises();
          reloadResult.fold(
            (failure) {
              _logFailure('LoadExercisesEvent (post-seed reload)', failure);
              emit(ExerciseError(failure.message));
            },
            (seeded) {
              AppLogger.info(
                'LoadExercisesEvent: post-seed reload returned '
                '${seeded.length} exercise(s)',
                category: 'exercise_bloc',
              );
              emit(ExercisesLoaded(seeded));
            },
          );
          return;
        }

        if (exercises.isEmpty) {
          AppLogger.warning(
            'LoadExercisesEvent: getAllExercises returned 0 rows '
            '(reseed already ran this session — skipping)',
            category: 'exercise_bloc',
          );
        } else {
          AppLogger.info(
            'LoadExercisesEvent: loaded ${exercises.length} exercise(s)',
            category: 'exercise_bloc',
          );
        }
        emit(ExercisesLoaded(exercises));
      },
    );
  }

  Future<void> _onLoadExerciseById(
    LoadExerciseByIdEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    emit(ExerciseLoading());
    final result = await getExerciseById(event.id);
    result.fold(
      (failure) {
        _logFailure('LoadExerciseByIdEvent(${event.id})', failure);
        emit(ExerciseError(failure.message));
      },
      (exercise) {
        if (exercise == null) {
          AppLogger.warning(
            'LoadExerciseByIdEvent(${event.id}): exercise not found',
            category: 'exercise_bloc',
          );
          emit(const ExerciseError('Exercise not found'));
        } else {
          emit(ExerciseLoaded(exercise));
        }
      },
    );
  }

  Future<void> _onLoadExercisesForMuscle(
    LoadExercisesForMuscleEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    emit(ExerciseLoading());
    final result = await getExercisesForMuscle(event.muscleGroup);
    result.fold((failure) {
      _logFailure('LoadExercisesForMuscleEvent(${event.muscleGroup})', failure);
      emit(ExerciseError(failure.message));
    }, (exercises) => emit(ExercisesLoaded(exercises)));
  }

  /// Loads the saved [MuscleFactor] rows for an exercise and emits
  /// [ExerciseFactorsLoaded].  Failures are logged but do not change state —
  /// the dialog gracefully falls back to default 1.0 weights.
  Future<void> _onLoadExerciseFactors(
    LoadExerciseFactorsEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    final result = await getMuscleFactorsForExercise(event.exerciseId);
    result.fold(
      (failure) {
        AppLogger.warning(
          'LoadExerciseFactorsEvent(${event.exerciseId}) failed — '
          '${failure.message}',
          category: 'exercise_bloc',
        );
        // Fail silently: the dialog retains default 1.0 weights.
      },
      (factors) {
        final factorMap = <String, double>{
          for (final f in factors) f.muscleGroup: f.factor,
        };
        emit(
          ExerciseFactorsLoaded(
            exerciseId: event.exerciseId,
            factors: factorMap,
          ),
        );
      },
    );
  }

  Future<void> _onAddExercise(
    AddExerciseEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    final result = await addExercise(
      event.exercise,
      muscleFactors: event.muscleFactors,
    );
    await result.fold(
      (failure) async {
        _logFailure('AddExerciseEvent(${event.exercise.name})', failure);
        emit(ExerciseError(failure.message));
      },
      (_) async {
        exerciseLookup.invalidate();
        emit(const ExerciseOperationSuccess('Exercise added successfully'));
        add(LoadExercisesEvent());
      },
    );
  }

  Future<void> _onUpdateExercise(
    UpdateExerciseEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    final result = await updateExercise(
      event.exercise,
      muscleFactors: event.muscleFactors,
    );
    await result.fold(
      (failure) async {
        _logFailure('UpdateExerciseEvent(${event.exercise.name})', failure);
        emit(ExerciseError(failure.message));
      },
      (_) async {
        exerciseLookup.invalidate();
        emit(const ExerciseOperationSuccess('Exercise updated successfully'));
        add(LoadExercisesEvent());
      },
    );
  }

  Future<void> _onDeleteExercise(
    DeleteExerciseEvent event,
    Emitter<ExerciseState> emit,
  ) async {
    final result = await deleteExercise(event.id);
    await result.fold(
      (failure) async {
        _logFailure('DeleteExerciseEvent(${event.id})', failure);
        emit(ExerciseError(failure.message));
      },
      (_) async {
        exerciseLookup.invalidate();
        emit(const ExerciseOperationSuccess('Exercise deleted successfully'));
        add(LoadExercisesEvent());
      },
    );
  }

  void _logFailure(String operation, Failure failure) {
    AppLogger.error(
      '$operation failed — ${failure.runtimeType}: ${failure.message}',
      category: 'exercise_bloc',
    );
  }
}
