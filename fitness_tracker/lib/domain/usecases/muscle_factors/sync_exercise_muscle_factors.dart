import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/muscle_groups.dart';
import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../entities/muscle_factor.dart';
import '../../repositories/muscle_factor_repository.dart';

class SyncExerciseMuscleFactors {
  SyncExerciseMuscleFactors(this.muscleFactorRepository);

  final MuscleFactorRepository muscleFactorRepository;
  final Uuid _uuid = const Uuid();

  /// Replaces all [MuscleFactor] rows for [exercise] with up-to-date values.
  ///
  /// When [muscleFactors] is supplied (simple-key → factor), each entry
  /// is clamped to [0.0, 1.0] and entries with factor ≤ 0 are skipped.
  /// When [muscleFactors] is null, every selected muscle receives factor 1.0
  /// (the original behaviour — preserves backwards-compatibility for callers
  /// that don't know about user-edited weights).
  Future<Either<Failure, void>> call(
    Exercise exercise, {
    Map<String, double>? muscleFactors,
  }) async {
    final deleteResult = await muscleFactorRepository
        .deleteMuscleFactorsByExerciseId(exercise.id);

    return deleteResult.fold((failure) async => Left(failure), (_) async {
      final normalizedMuscles = exercise.muscleGroups
          .map((muscle) => muscle.trim().toLowerCase())
          .where(_isKnownMuscle)
          .toSet()
          .toList();

      if (normalizedMuscles.isEmpty) {
        return const Right(null);
      }

      final List<MuscleFactor> factors = [];
      for (final muscleGroup in normalizedMuscles) {
        final double factor;
        if (muscleFactors != null) {
          final raw = (muscleFactors[muscleGroup] ?? 1.0).clamp(0.0, 1.0);
          if (raw <= 0.0) continue; // skip zero-weight entries per spec
          factor = raw;
        } else {
          factor = 1.0;
        }
        factors.add(
          MuscleFactor(
            id: _uuid.v4(),
            exerciseId: exercise.id,
            muscleGroup: muscleGroup,
            factor: factor,
          ),
        );
      }

      if (factors.isEmpty) {
        return const Right(null);
      }

      return muscleFactorRepository.addMuscleFactorsBatch(factors);
    });
  }

  /// Accepts both granular taxonomy keys (e.g. `'mid-chest'` from seed data)
  /// and simple taxonomy keys (e.g. `'chest'` from user-created exercises) so
  /// that both exercise sources store muscle factors correctly.
  static bool _isKnownMuscle(String muscle) =>
      MuscleStimulus.isValidMuscleGroup(muscle) || MuscleGroups.isValid(muscle);
}
