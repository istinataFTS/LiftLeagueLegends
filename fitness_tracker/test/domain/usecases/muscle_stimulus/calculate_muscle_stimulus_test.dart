import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

// intensity=5, maxIntensity=5, exponent=1.35 → (1.0)^1.35 = 1.0
// stimulus = sets × intensityFactor × exerciseFactor = 1 × 1.0 × 1.0 = 1.0
const _maxIntensity = 5;

void main() {
  late MockMuscleFactorRepository mockFactorRepo;
  late CalculateMuscleStimulus useCase;

  setUp(() {
    mockFactorRepo = MockMuscleFactorRepository();
    useCase = CalculateMuscleStimulus(muscleFactorRepository: mockFactorRepo);
  });

  group('CalculateMuscleStimulus', () {
    group('calculateForSet', () {
      test('returns ValidationFailure for negative sets', () async {
        final result = await useCase.calculateForSet(
          exerciseId: 'ex-1',
          sets: -1,
          intensity: 3,
        );

        expect(
          result,
          const Left(ValidationFailure('Sets cannot be negative')),
        );
        verifyNever(() => mockFactorRepo.getFactorsForExercise(any()));
      });

      test('returns ValidationFailure for intensity above max (6)', () async {
        final result = await useCase.calculateForSet(
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 6,
        );

        expect(
          result,
          const Left(ValidationFailure('Intensity must be between 0 and 5')),
        );
        verifyNever(() => mockFactorRepo.getFactorsForExercise(any()));
      });

      test('returns empty map when exercise has no muscle factors', () async {
        when(
          () => mockFactorRepo.getFactorsForExercise('ex-1'),
        ).thenAnswer((_) async => const Right([]));

        final result = await useCase.calculateForSet(
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 3,
        );

        expect(result.isRight(), isTrue);
        expect((result as Right).value, <String, double>{});
      });

      test('computes stimulus per muscle group from factors', () async {
        final chestFactor = MuscleFactor(
          id: 'f-1',
          exerciseId: 'ex-1',
          muscleGroup: 'chest',
          factor: 1.0,
        );

        when(
          () => mockFactorRepo.getFactorsForExercise('ex-1'),
        ).thenAnswer((_) async => Right([chestFactor]));

        // intensity=5 → intensityFactor=(5/5)^1.35=1.0 → stimulus=1×1.0×1.0=1.0
        final result = await useCase.calculateForSet(
          exerciseId: 'ex-1',
          sets: 1,
          intensity: _maxIntensity,
        );

        expect(result.isRight(), isTrue);
        final stimuli = (result as Right).value as Map<String, double>;
        expect(stimuli['chest'], closeTo(1.0, 0.001));
      });

      test('propagates repository failure', () async {
        const failure = DatabaseFailure('db error');
        when(
          () => mockFactorRepo.getFactorsForExercise('ex-1'),
        ).thenAnswer((_) async => const Left(failure));

        final result = await useCase.calculateForSet(
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 3,
        );

        expect(result, const Left(failure));
      });
    });

    group('calculateForWorkout', () {
      test('returns empty map for empty workout set list', () async {
        final result = await useCase.calculateForWorkout(workoutSets: []);

        expect(result.isRight(), isTrue);
        expect((result as Right).value, <String, double>{});
        verifyNever(() => mockFactorRepo.getFactorsForExercise(any()));
      });

      test(
        'accumulates stimulus across multiple sets for the same muscle',
        () async {
          final chestFactor = MuscleFactor(
            id: 'f-1',
            exerciseId: 'ex-1',
            muscleGroup: 'chest',
            factor: 1.0,
          );

          when(
            () => mockFactorRepo.getFactorsForExercise('ex-1'),
          ).thenAnswer((_) async => Right([chestFactor]));

          // Two sets at max intensity: each gives stimulus=1.0 → total=2.0
          final result = await useCase.calculateForWorkout(
            workoutSets: [
              const WorkoutSetInput(
                exerciseId: 'ex-1',
                intensity: _maxIntensity,
              ),
              const WorkoutSetInput(
                exerciseId: 'ex-1',
                intensity: _maxIntensity,
              ),
            ],
          );

          expect(result.isRight(), isTrue);
          final stimuli = (result as Right).value as Map<String, double>;
          expect(stimuli['chest'], closeTo(2.0, 0.001));
        },
      );
    });

    group('calculateIntensityFactor', () {
      test('returns 0.0 for zero intensity (warm-up)', () {
        expect(useCase.calculateIntensityFactor(0), 0.0);
      });

      test('returns 1.0 for maximum intensity', () {
        expect(
          useCase.calculateIntensityFactor(_maxIntensity),
          closeTo(1.0, 0.001),
        );
      });
    });

    group('validateInputs', () {
      test('returns false for empty exerciseId', () {
        expect(
          useCase.validateInputs(exerciseId: '', sets: 1, intensity: 3),
          isFalse,
        );
      });

      test('returns false for negative sets', () {
        expect(
          useCase.validateInputs(exerciseId: 'ex-1', sets: -1, intensity: 3),
          isFalse,
        );
      });

      test('returns false for intensity above max', () {
        expect(
          useCase.validateInputs(exerciseId: 'ex-1', sets: 1, intensity: 6),
          isFalse,
        );
      });

      test('returns true for valid inputs', () {
        expect(
          useCase.validateInputs(exerciseId: 'ex-1', sets: 1, intensity: 3),
          isTrue,
        );
      });
    });
  });
}
