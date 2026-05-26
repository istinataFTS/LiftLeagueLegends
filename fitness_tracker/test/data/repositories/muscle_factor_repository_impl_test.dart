import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/muscle_factor_local_datasource.dart';
import 'package:fitness_tracker/data/models/muscle_factor_model.dart';
import 'package:fitness_tracker/data/repositories/muscle_factor_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleFactorLocalDataSource extends Mock
    implements MuscleFactorLocalDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const MuscleFactorModel(
        id: 'fallback',
        exerciseId: 'fallback-exercise',
        muscleGroup: 'chest',
        factor: 1.0,
      ),
    );
  });

  late MockMuscleFactorLocalDataSource localDataSource;
  late MuscleFactorRepositoryImpl repository;

  const MuscleFactorModel chestFactor = MuscleFactorModel(
    id: 'factor-1',
    exerciseId: 'exercise-1',
    muscleGroup: 'chest',
    factor: 1.0,
  );

  const MuscleFactorModel tricepsFactor = MuscleFactorModel(
    id: 'factor-2',
    exerciseId: 'exercise-1',
    muscleGroup: 'triceps',
    factor: 0.5,
  );

  setUp(() {
    localDataSource = MockMuscleFactorLocalDataSource();
    repository = MuscleFactorRepositoryImpl(localDataSource: localDataSource);
  });

  group('getFactorById', () {
    test('returns factor when datasource succeeds', () async {
      when(
        () => localDataSource.getFactorById('factor-1'),
      ).thenAnswer((_) async => chestFactor);

      final result = await repository.getFactorById('factor-1');

      expect(result, const Right(chestFactor));
      verify(() => localDataSource.getFactorById('factor-1')).called(1);
    });

    test('returns failure when datasource throws', () async {
      when(
        () => localDataSource.getFactorById('factor-1'),
      ).thenThrow(const CacheDatabaseException('lookup failed'));

      final result = await repository.getFactorById('factor-1');

      expect(result, const Left(DatabaseFailure('lookup failed')));
    });
  });

  group('getFactorsByMuscleGroup', () {
    test('filters models by muscle group', () async {
      when(() => localDataSource.getAllFactors()).thenAnswer(
        (_) async => const <MuscleFactorModel>[chestFactor, tricepsFactor],
      );

      final result = await repository.getFactorsByMuscleGroup('chest');

      expect(result.isRight(), isTrue);
      expect((result as Right).value, const <MuscleFactor>[chestFactor]);
      verify(() => localDataSource.getAllFactors()).called(1);
    });
  });

  group('addMuscleFactor', () {
    test('maps entity to model and forwards to datasource', () async {
      const MuscleFactor entity = MuscleFactor(
        id: 'factor-3',
        exerciseId: 'exercise-9',
        muscleGroup: 'back',
        factor: 0.8,
      );

      when(() => localDataSource.addFactor(any())).thenAnswer((_) async {});

      final result = await repository.addMuscleFactor(entity);

      expect(result, const Right(null));
      verify(
        () => localDataSource.addFactor(
          const MuscleFactorModel(
            id: 'factor-3',
            exerciseId: 'exercise-9',
            muscleGroup: 'back',
            factor: 0.8,
          ),
        ),
      ).called(1);
    });
  });

  group('addMuscleFactorsBatch', () {
    test('maps entities to models before saving batch', () async {
      const List<MuscleFactor> factors = <MuscleFactor>[
        MuscleFactor(
          id: 'factor-1',
          exerciseId: 'exercise-1',
          muscleGroup: 'chest',
          factor: 1.0,
        ),
        MuscleFactor(
          id: 'factor-2',
          exerciseId: 'exercise-1',
          muscleGroup: 'triceps',
          factor: 0.5,
        ),
      ];

      when(
        () => localDataSource.addFactorsBatch(any()),
      ).thenAnswer((_) async {});

      final result = await repository.addMuscleFactorsBatch(factors);

      expect(result, const Right(null));
      verify(
        () => localDataSource.addFactorsBatch(const <MuscleFactorModel>[
          MuscleFactorModel(
            id: 'factor-1',
            exerciseId: 'exercise-1',
            muscleGroup: 'chest',
            factor: 1.0,
          ),
          MuscleFactorModel(
            id: 'factor-2',
            exerciseId: 'exercise-1',
            muscleGroup: 'triceps',
            factor: 0.5,
          ),
        ]),
      ).called(1);
    });
  });
}
