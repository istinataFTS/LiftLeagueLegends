import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_all_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercise_by_id.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercises_for_muscle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

void main() {
  late MockExerciseRepository repository;
  late MockAuthenticatedDataSourcePreferenceResolver resolver;

  late GetAllExercises getAllExercises;
  late GetExerciseById getExerciseById;
  late GetExercisesForMuscle getExercisesForMuscle;

  final exercise = Exercise(
    id: 'exercise-1',
    name: 'Bench Press',
    muscleGroups: <String>['chest', 'triceps'],
    createdAt: DateTime(2026, 3, 26),
  );

  setUp(() {
    repository = MockExerciseRepository();
    resolver = MockAuthenticatedDataSourcePreferenceResolver();

    getAllExercises = GetAllExercises(
      repository,
      sourcePreferenceResolver: resolver,
    );
    getExerciseById = GetExerciseById(
      repository,
      sourcePreferenceResolver: resolver,
    );
    getExercisesForMuscle = GetExercisesForMuscle(
      repository,
      sourcePreferenceResolver: resolver,
    );
  });

  test('GetAllExercises uses resolved source preference', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => repository.getAllExercises(
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => Right(<Exercise>[exercise]));

    final result = await getAllExercises();

    expect(result.isRight(), isTrue);
    expect((result as Right).value, <Exercise>[exercise]);
    verify(
      () => repository.getAllExercises(
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });

  test('GetExerciseById uses resolved source preference', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => repository.getExerciseById(
        'exercise-1',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => Right(exercise));

    final result = await getExerciseById('exercise-1');

    expect(result, Right<Failure, Exercise?>(exercise));
    verify(
      () => repository.getExerciseById(
        'exercise-1',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });

  test('GetExercisesForMuscle uses resolved source preference', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => repository.getExercisesForMuscle(
        'chest',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => Right(<Exercise>[exercise]));

    final result = await getExercisesForMuscle('chest');

    expect(result.isRight(), isTrue);
    expect((result as Right).value, <Exercise>[exercise]);
    verify(
      () => repository.getExercisesForMuscle(
        'chest',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });
}
