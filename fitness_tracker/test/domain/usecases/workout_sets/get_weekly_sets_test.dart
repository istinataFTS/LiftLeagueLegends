import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_weekly_sets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

void main() {
  late MockWorkoutSetRepository repository;
  late MockAuthenticatedDataSourcePreferenceResolver resolver;
  late GetWeeklySets usecase;

  setUp(() {
    repository = MockWorkoutSetRepository();
    resolver = MockAuthenticatedDataSourcePreferenceResolver();
    usecase = GetWeeklySets(repository, sourcePreferenceResolver: resolver);
  });

  test('uses resolved source preference for weekly reads', () async {
    when(
      () => resolver.resolveReadPreference(),
    ).thenAnswer((_) async => DataSourcePreference.remoteThenLocal);
    when(
      () => repository.getSetsByDateRange(
        any(),
        any(),
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).thenAnswer((_) async => const Right(<WorkoutSet>[]));

    final result = await usecase();

    expect(result, const Right<Failure, List<WorkoutSet>>(<WorkoutSet>[]));

    verify(
      () => repository.getSetsByDateRange(
        any(),
        any(),
        sourcePreference: DataSourcePreference.remoteThenLocal,
      ),
    ).called(1);
  });
}
