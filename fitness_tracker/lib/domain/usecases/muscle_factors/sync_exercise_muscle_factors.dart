import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/legacy_muscle_group_map.dart';
import '../../../core/constants/muscle_factor_combine.dart';
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
  /// Every incoming key — both `exercise.muscleGroups` and the [muscleFactors]
  /// map — is canonicalised at the boundary so any stray legacy key from an
  /// in-flight edit is normalised before storage. Only canonical keys are
  /// persisted (the v26 taxonomy).
  ///
  /// When [muscleFactors] is supplied (canonical-key → factor), each entry
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
      final List<String> canonicalMuscles = exercise.muscleGroups
          .map(
            (muscle) => LegacyMuscleGroupMap.canonicalizeMuscleKey(
              muscle.trim().toLowerCase(),
            ),
          )
          .where(MuscleStimulus.isValidMuscleGroup)
          .toSet()
          .toList();

      if (canonicalMuscles.isEmpty) {
        return const Right(null);
      }

      // Canonicalise the supplied factor keys too, collapsing any legacy
      // duplicates with the same MAX rule used by the seed and migration.
      final Map<String, double>? canonicalFactors = muscleFactors == null
          ? null
          : combineCanonicalFactors(
              muscleFactors.entries.map(
                (entry) =>
                    MapEntry(entry.key.trim().toLowerCase(), entry.value),
              ),
            );

      final List<MuscleFactor> factors = [];
      for (final muscleGroup in canonicalMuscles) {
        final double factor;
        if (canonicalFactors != null) {
          final raw = (canonicalFactors[muscleGroup] ?? 1.0).clamp(0.0, 1.0);
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
}
