import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_exercise_personal_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class _MockResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

void main() {
  late _MockWorkoutSetRepository repository;
  late _MockResolver resolver;
  late GetExercisePersonalRecord usecase;

  WorkoutSet set({
    required String id,
    required double weight,
    required int reps,
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: 'ex-1',
      reps: reps,
      weight: weight,
      intensity: 3,
      date: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
  }

  setUp(() {
    repository = _MockWorkoutSetRepository();
    resolver = _MockResolver();
    usecase = GetExercisePersonalRecord(
      repository,
      sourcePreferenceResolver: resolver,
    );

    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.localOnly);
  });

  test('returns null when no sets exist for exercise', () async {
    when(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.localOnly,
      ),
    ).thenAnswer((_) async => const Right<Failure, List<WorkoutSet>>([]));

    final result = await usecase('ex-1');

    expect(result, const Right<Failure, WorkoutSet?>(null));
  });

  test('picks set with the heaviest weight', () async {
    final s1 = set(id: 's1', weight: 80, reps: 10);
    final s2 = set(id: 's2', weight: 100, reps: 5);
    final s3 = set(id: 's3', weight: 90, reps: 12);
    when(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.localOnly,
      ),
    ).thenAnswer((_) async => Right(<WorkoutSet>[s1, s2, s3]));

    final result = await usecase('ex-1');

    expect(result.getOrElse(() => null)?.id, 's2');
  });

  test('breaks weight tie by higher reps', () async {
    final s1 = set(id: 's1', weight: 100, reps: 5);
    final s2 = set(id: 's2', weight: 100, reps: 8);
    final s3 = set(id: 's3', weight: 100, reps: 6);
    when(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.localOnly,
      ),
    ).thenAnswer((_) async => Right(<WorkoutSet>[s1, s2, s3]));

    final result = await usecase('ex-1');

    expect(result.getOrElse(() => null)?.id, 's2');
  });

  test('propagates repository failure', () async {
    when(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.localOnly,
      ),
    ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));

    final result = await usecase('ex-1');

    expect(result.isLeft(), isTrue);
    expect(result.fold((f) => f.message, (_) => null), 'boom');
  });

  test('uses resolved read preference', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => const Right<Failure, List<WorkoutSet>>([]));

    await usecase('ex-1');

    verify(
      () => repository.getSetsByExerciseId(
        'ex-1',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });
}
