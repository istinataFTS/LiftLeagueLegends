import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../entities/stimulus_calculation_rules.dart';
import '../../repositories/muscle_factor_repository.dart';

/// Use case for calculating muscle stimulus from workout sets.
class CalculateMuscleStimulus {
  final MuscleFactorRepository muscleFactorRepository;

  const CalculateMuscleStimulus({required this.muscleFactorRepository});

  /// Returns a map of muscleGroup -> stimulus value.
  Future<Either<Failure, Map<String, double>>> calculateForSet({
    required String exerciseId,
    required int sets,
    required int intensity,
  }) async {
    try {
      if (sets < 0) {
        return const Left(ValidationFailure('Sets cannot be negative'));
      }

      if (!StimulusCalculationRules.validateIntensity(intensity)) {
        return const Left(
          ValidationFailure('Intensity must be between 0 and 5'),
        );
      }

      final factorsResult = await muscleFactorRepository.getFactorsForExercise(
        exerciseId,
      );

      return factorsResult.fold((failure) => Left(failure), (factors) {
        if (factors.isEmpty) {
          // A valid exercise should always have at least one muscle factor.
          // An empty result here means the seed for this exercise is missing
          // (e.g. a user-created exercise that skipped `SyncExerciseMuscleFactors`,
          // or a wiped factor table).  We keep returning `Right({})` so callers
          // that iterate many sets — like `RebuildMuscleStimulusFromWorkoutHistory`
          // — are not forced to abort the whole rebuild.  Instead we surface
          // the situation as a warning so devs can spot it in production logs
          // and callers can show a non-fatal UI banner.
          AppLogger.warning(
            'No muscle factors for exerciseId=$exerciseId — '
            'the body map will not update for this set.',
            category: 'stimulus',
          );
          return const Right({});
        }

        final muscleStimuli = <String, double>{};

        for (final factor in factors) {
          final setStimulus = StimulusCalculationRules.calculateSetStimulus(
            sets: sets,
            intensity: intensity,
            exerciseFactor: factor.factor,
          );

          muscleStimuli[factor.muscleGroup] = setStimulus;
        }

        return Right(muscleStimuli);
      });
    } catch (e) {
      return Left(UnexpectedFailure('Failed to calculate stimulus: $e'));
    }
  }

  Future<Either<Failure, Map<String, double>>> calculateForWorkout({
    required List<WorkoutSetInput> workoutSets,
  }) async {
    try {
      final totalStimuli = <String, double>{};

      for (final setInput in workoutSets) {
        final setResult = await calculateForSet(
          exerciseId: setInput.exerciseId,
          sets: 1,
          intensity: setInput.intensity,
        );

        setResult.fold((_) {}, (muscleStimuli) {
          for (final entry in muscleStimuli.entries) {
            totalStimuli[entry.key] =
                (totalStimuli[entry.key] ?? 0.0) + entry.value;
          }
        });
      }

      return Right(totalStimuli);
    } catch (e) {
      return Left(
        UnexpectedFailure('Failed to calculate workout stimulus: $e'),
      );
    }
  }

  /// Returns `muscleGroup → factor (0..1)` for [exerciseId].
  ///
  /// Empty map when factors are unseeded (warning logged, matching the
  /// behaviour of [calculateForSet] in the same situation). Use this to
  /// compute volume (weight×reps×factor) in the rebuild loop instead of
  /// calling [calculateForSet] twice per exercise.
  Future<Either<Failure, Map<String, double>>> factorsForExercise(
    String exerciseId,
  ) async {
    try {
      final result = await muscleFactorRepository.getFactorsForExercise(
        exerciseId,
      );
      return result.fold((f) => Left(f), (factors) {
        if (factors.isEmpty) {
          AppLogger.warning(
            'No muscle factors for exerciseId=$exerciseId — '
            'body map will not update.',
            category: 'stimulus',
          );
          return const Right(<String, double>{});
        }
        return Right({for (final f in factors) f.muscleGroup: f.factor});
      });
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get muscle factors: $e'));
    }
  }

  double calculateIntensityFactor(int intensity) {
    return StimulusCalculationRules.calculateIntensityFactor(intensity);
  }

  bool validateInputs({
    required String exerciseId,
    required int sets,
    required int intensity,
  }) {
    if (exerciseId.trim().isEmpty) return false;
    if (sets < 0) return false;
    return StimulusCalculationRules.validateIntensity(intensity);
  }
}

class WorkoutSetInput {
  final String exerciseId;
  final int intensity;

  const WorkoutSetInput({required this.exerciseId, required this.intensity});
}
