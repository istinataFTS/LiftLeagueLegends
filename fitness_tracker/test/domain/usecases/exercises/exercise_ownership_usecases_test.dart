import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/usecases/exercises/add_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/update_exercise.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/sync_exercise_muscle_factors.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

class MockRebuildMuscleStimulusFromWorkoutHistory extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

void main() {
  late MockExerciseRepository exerciseRepository;
  late MockAppSessionRepository appSessionRepository;
  late MockMuscleFactorRepository muscleFactorRepository;
  late MockRebuildMuscleStimulusFromWorkoutHistory
  rebuildMuscleStimulusFromWorkoutHistory;

  late AddExercise addExercise;
  late UpdateExercise updateExercise;

  final baseExercise = Exercise(
    id: 'exercise-1',
    name: 'Bench Press',
    muscleGroups: <String>['chest', 'triceps'],
    createdAt: DateTime(2026, 3, 26),
  );

  setUpAll(() {
    registerFallbackValue(
      Exercise(
        id: 'fallback-exercise',
        name: 'Fallback Exercise',
        muscleGroups: const <String>['mid-chest'],
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    registerFallbackValue(const <MuscleFactor>[]);
  });

  setUp(() {
    exerciseRepository = MockExerciseRepository();
    appSessionRepository = MockAppSessionRepository();
    muscleFactorRepository = MockMuscleFactorRepository();
    rebuildMuscleStimulusFromWorkoutHistory =
        MockRebuildMuscleStimulusFromWorkoutHistory();

    addExercise = AddExercise(
      exerciseRepository,
      appSessionRepository: appSessionRepository,
      syncExerciseMuscleFactors: SyncExerciseMuscleFactors(
        muscleFactorRepository,
      ),
    );

    updateExercise = UpdateExercise(
      exerciseRepository,
      appSessionRepository: appSessionRepository,
      syncExerciseMuscleFactors: SyncExerciseMuscleFactors(
        muscleFactorRepository,
      ),
      rebuildMuscleStimulusFromWorkoutHistory:
          rebuildMuscleStimulusFromWorkoutHistory,
    );

    when(
      () => exerciseRepository.addExercise(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => exerciseRepository.updateExercise(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => muscleFactorRepository.deleteMuscleFactorsByExerciseId(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => muscleFactorRepository.addMuscleFactorsBatch(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => rebuildMuscleStimulusFromWorkoutHistory(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  test(
    'AddExercise attaches authenticated ownerUserId before persisting',
    () async {
      when(() => appSessionRepository.getCurrentSession()).thenAnswer(
        (_) async => const Right(
          AppSession(
            user: AppUser(id: 'user-1', email: 'user@test.com'),
          ),
        ),
      );

      final result = await addExercise(baseExercise);

      expect(result, const Right(null));

      verify(
        () => exerciseRepository.addExercise(
          baseExercise.copyWith(ownerUserId: 'user-1'),
        ),
      ).called(1);
      verify(
        () => muscleFactorRepository.deleteMuscleFactorsByExerciseId(
          'exercise-1',
        ),
      ).called(1);
      verify(
        () => muscleFactorRepository.addMuscleFactorsBatch(any()),
      ).called(1);
    },
  );

  test(
    'UpdateExercise attaches authenticated ownerUserId before persisting',
    () async {
      when(() => appSessionRepository.getCurrentSession()).thenAnswer(
        (_) async => const Right(
          AppSession(
            user: AppUser(id: 'user-1', email: 'user@test.com'),
          ),
        ),
      );

      final result = await updateExercise(baseExercise);

      expect(result, const Right(null));

      verify(
        () => exerciseRepository.updateExercise(
          baseExercise.copyWith(ownerUserId: 'user-1'),
        ),
      ).called(1);
      verify(
        () => muscleFactorRepository.deleteMuscleFactorsByExerciseId(
          'exercise-1',
        ),
      ).called(1);
      verify(
        () => muscleFactorRepository.addMuscleFactorsBatch(any()),
      ).called(1);
      verify(() => rebuildMuscleStimulusFromWorkoutHistory(any())).called(1);
    },
  );

  // Guest-session and session-lookup-failure tests removed: AddExercise and
  // UpdateExercise now propagate a session-lookup failure rather than
  // falling back to a sentinel guest owner.
}
