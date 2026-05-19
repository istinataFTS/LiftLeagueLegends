import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_all_workout_sets.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      WorkoutSet(
        id: 'fallback-set',
        exerciseId: 'fallback-exercise',
        reps: 10,
        weight: 80,
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockWorkoutSetRepository workoutSetRepository;
  late MockExerciseRepository exerciseRepository;
  late MockAuthenticatedDataSourcePreferenceResolver resolver;

  late GetAllWorkoutSets getAllWorkoutSets;
  late GetSetsByDateRange getSetsByDateRange;

  final startDate = DateTime(2026, 3, 1);
  final endDate = DateTime(2026, 3, 31);

  final workoutSet = WorkoutSet(
    id: 'set-1',
    exerciseId: 'exercise-1',
    reps: 10,
    weight: 80,
    intensity: 8,
    date: DateTime(2026, 3, 26),
    createdAt: DateTime(2026, 3, 26),
  );

  final exercise = Exercise(
    id: 'exercise-1',
    name: 'Bench Press',
    muscleGroups: <String>['chest', 'triceps'],
    createdAt: DateTime(2026, 3, 26),
  );

  setUp(() {
    workoutSetRepository = MockWorkoutSetRepository();
    exerciseRepository = MockExerciseRepository();
    resolver = MockAuthenticatedDataSourcePreferenceResolver();

    getAllWorkoutSets = GetAllWorkoutSets(
      workoutSetRepository,
      sourcePreferenceResolver: resolver,
    );

    getSetsByDateRange = GetSetsByDateRange(
      workoutSetRepository: workoutSetRepository,
      exerciseRepository: exerciseRepository,
      sourcePreferenceResolver: resolver,
    );
  });

  test('GetAllWorkoutSets uses resolved source preference', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => workoutSetRepository.getAllSets(
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => Right(<WorkoutSet>[workoutSet]));

    final result = await getAllWorkoutSets();

    expect(result.isRight(), isTrue);
    expect((result as Right).value, <WorkoutSet>[workoutSet]);
    verify(
      () => workoutSetRepository.getAllSets(
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });

  test(
    'GetSetsByDateRange uses resolved source preference for sets and exercises',
    () async {
      when(
        () => resolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
      when(
        () => workoutSetRepository.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.remoteThenLocal,
        ),
      ).thenAnswer((_) async => Right(<WorkoutSet>[workoutSet]));
      when(
        () => exerciseRepository.getAllExercises(
          sourcePreference: DataSourcePreference.remoteThenLocal,
        ),
      ).thenAnswer((_) async => Right(<Exercise>[exercise]));

      final result = await getSetsByDateRange(
        startDate: startDate,
        endDate: endDate,
        muscleGroup: 'chest',
      );

      expect(result.isRight(), isTrue);
      expect((result as Right).value, <WorkoutSet>[workoutSet]);
      verify(
        () => workoutSetRepository.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.remoteThenLocal,
        ),
      ).called(1);
      verify(
        () => exerciseRepository.getAllExercises(
          sourcePreference: DataSourcePreference.remoteThenLocal,
        ),
      ).called(1);
    },
  );
}
