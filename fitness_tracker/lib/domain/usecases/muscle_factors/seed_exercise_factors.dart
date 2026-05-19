import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../config/env_config.dart';
import '../../../core/constants/exercise_muscle_factors_data.dart';
import '../../../core/errors/failures.dart';
import '../../entities/muscle_factor.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/muscle_factor_repository.dart';

/// Use case to seed exercise muscle factors into the database
///
/// This populates the exercise_muscle_factors table with comprehensive
/// biomechanically-accurate factor assignments for all seeded exercises.
///
/// Should be executed after exercises are seeded.
class SeedExerciseFactors {
  final MuscleFactorRepository muscleFactorRepository;
  final ExerciseRepository exerciseRepository;
  final _uuid = const Uuid();

  const SeedExerciseFactors({
    required this.muscleFactorRepository,
    required this.exerciseRepository,
  });

  /// Seeds missing entries in the `exercise_muscle_factors` table.
  ///
  /// Muscle factors are **domain data** (biomechanically-accurate muscle
  /// mappings), not demo content.  Pass [allowHealingWhenEmpty] = true from
  /// a "heal" path to bypass [EnvConfig.seedDefaultData] when no factors
  /// exist for the current exercises — that way a production-like build
  /// (seeding disabled) still self-heals if factors were lost or never
  /// populated.
  ///
  /// Each call is **per-exercise idempotent**: it only inserts factor rows for
  /// exercises that currently have none.  Exercises that already have factors
  /// are skipped without any writes.  This means calling this use-case after
  /// every sign-in is safe and cheap in the steady state.
  ///
  /// Pass [forceReseed] via [EnvConfig] to wipe all factors and re-seed from
  /// scratch (dev/debug only).
  Future<Either<Failure, int>> call({
    bool allowHealingWhenEmpty = false,
  }) async {
    try {
      if (!EnvConfig.seedDefaultData && !allowHealingWhenEmpty) {
        _log('Muscle factor seeding disabled in environment config');
        return const Right(0);
      }

      _log('Starting exercise muscle factors seeding...');
      _log('Seed data version: ${EnvConfig.seedDataVersion}');

      final exercisesResult = await exerciseRepository.getAllExercises();

      return await exercisesResult.fold(
        (failure) async {
          _logError('Failed to get exercises: ${failure.message}');
          return Left(failure);
        },
        (exercises) async {
          if (exercises.isEmpty) {
            _logWarning(
              'No exercises found in database. Seed exercises first.',
            );
            return const Left(
              DatabaseFailure('No exercises to assign factors to'),
            );
          }

          _log('Found ${exercises.length} exercises in database');

          if (EnvConfig.forceReseed) {
            _logWarning('Force reseed enabled - clearing existing factors');
            await _clearExistingFactors();
            return _seedAllFactors(exercises);
          }

          return _seedMissingFactors(exercises);
        },
      );
    } catch (e) {
      _logError('Unexpected error during factor seeding: $e');
      return Left(DatabaseFailure('Factor seeding failed: $e'));
    }
  }

  /// Clear existing muscle factor data (used with force reseed)
  Future<void> _clearExistingFactors() async {
    _log('Clearing existing muscle factor data...');

    try {
      await muscleFactorRepository.clearAllFactors();
      _log('Successfully cleared existing factors');
    } catch (e) {
      _logError('Failed to clear existing factors: $e');
      rethrow;
    }
  }

  /// Seeds factors only for exercises that currently have none.
  ///
  /// Uses a single [getAllFactors] query to determine which exercise IDs
  /// already have at least one factor row, then batch-inserts only what is
  /// missing.  O(1) DB reads regardless of exercise count.
  Future<Either<Failure, int>> _seedMissingFactors(
    List<dynamic> exercises,
  ) async {
    // One query — build the set of exercise IDs that already have factors.
    final existingResult = await muscleFactorRepository.getAllFactors();
    final existingExerciseIds = existingResult.fold(
      (_) => <String>{},
      (factors) => factors.map((f) => f.exerciseId).toSet(),
    );

    final toInsert = <MuscleFactor>[];
    int alreadyCovered = 0;
    int noDataDefined = 0;

    for (final exercise in exercises) {
      if (existingExerciseIds.contains(exercise.id)) {
        alreadyCovered++;
        continue;
      }

      // Name-normalized lookup — tolerates "Sit Ups" vs "Sit-ups" etc.
      // See [ExerciseMuscleFactorsData._normalizeName].
      final factorsData = ExerciseMuscleFactorsData.getFactorsForExercise(
        exercise.name,
      );
      if (factorsData == null) {
        noDataDefined++;
        continue;
      }

      for (final factorData in factorsData) {
        toInsert.add(
          factorData.toEntity(id: _uuid.v4(), exerciseId: exercise.id),
        );
      }
    }

    if (alreadyCovered > 0) {
      _log('$alreadyCovered exercises already have factors — skipped');
    }
    if (noDataDefined > 0) {
      _logVerbose('$noDataDefined exercises have no factor data defined');
    }

    if (toInsert.isEmpty) {
      _log('All exercises with defined factors are already covered.');
      return const Right(0);
    }

    _log('Healing: inserting ${toInsert.length} missing factor assignments...');

    final result = await muscleFactorRepository.addMuscleFactorsBatch(toInsert);
    return result.fold(
      (failure) {
        _logError('Batch factor insert failed: ${failure.message}');
        return Left(failure);
      },
      (_) {
        _log('========== Factor Seeding Complete ==========');
        _log('Successfully healed: ${toInsert.length} muscle factors');
        _log('============================================');
        if (EnvConfig.enableSeedingLogs) {
          _validateSeeding(exercises);
        }
        return Right(toInsert.length);
      },
    );
  }

  /// Full re-seed used only when [EnvConfig.forceReseed] is true.
  ///
  /// Batch-inserts all factor assignments for every exercise in the database
  /// that has a definition in [ExerciseMuscleFactorsData].
  Future<Either<Failure, int>> _seedAllFactors(List<dynamic> exercises) async {
    _log('Seeding exercise muscle factors...');

    _log(
      'Total exercises with factors: ${ExerciseMuscleFactorsData.totalExercises}',
    );
    _log(
      'Total factor assignments: ${ExerciseMuscleFactorsData.totalFactorAssignments}',
    );

    final toInsert = <MuscleFactor>[];
    int skippedCount = 0;

    // Iterate DB exercises and look up factors by normalized name — keeps
    // the force-reseed path tolerant of the same spelling drift handled in
    // [_seedMissingFactors] (e.g. "Sit Ups" vs seed key "Sit-ups").
    for (final exercise in exercises) {
      final factorsData = ExerciseMuscleFactorsData.getFactorsForExercise(
        exercise.name,
      );
      if (factorsData == null) {
        _logWarning(
          'No factor data defined for exercise "${exercise.name}", skipping',
        );
        skippedCount++;
        continue;
      }

      for (final factorData in factorsData) {
        toInsert.add(
          factorData.toEntity(id: _uuid.v4(), exerciseId: exercise.id),
        );
      }
    }

    if (skippedCount > 0) {
      _logWarning('Skipped: $skippedCount exercises (not in database)');
    }

    if (toInsert.isEmpty) {
      return const Left(DatabaseFailure('Failed to seed any muscle factors'));
    }

    final result = await muscleFactorRepository.addMuscleFactorsBatch(toInsert);
    return result.fold(
      (failure) {
        _logError('Batch factor insert failed: ${failure.message}');
        return Left(failure);
      },
      (_) {
        _log('========== Factor Seeding Complete ==========');
        _log('Successfully seeded: ${toInsert.length} muscle factors');
        _log('============================================');
        if (EnvConfig.enableSeedingLogs) {
          _validateSeeding(exercises);
        }
        return Right(toInsert.length);
      },
    );
  }

  /// Validates that all exercises have at least one factor.
  ///
  /// Uses a single [getAllFactors] query — O(1) DB reads — rather than one
  /// query per exercise.  Runs only when [EnvConfig.enableSeedingLogs] is
  /// true so it never executes in non-logging production builds.
  void _validateSeeding(List<dynamic> exercises) {
    muscleFactorRepository.getAllFactors().then((result) {
      result.fold(
        (failure) => _logError('Validation query failed: ${failure.message}'),
        (allFactors) {
          final coveredIds = allFactors.map((f) => f.exerciseId).toSet();
          final missing = exercises
              .where((e) => !coveredIds.contains(e.id))
              .map((e) => e.name)
              .toList();

          if (missing.isEmpty) {
            _log('✅ All exercises have muscle factors assigned');
          } else {
            _logWarning(
              '⚠️  ${missing.length} exercises missing factors: '
              '${missing.join(', ')}',
            );
          }
        },
      );
    });
  }

  /// Validate seeding environment (optional pre-check)
  bool validateEnvironment() {
    if (EnvConfig.isProduction && EnvConfig.forceReseed) {
      _logError('CRITICAL: Force reseed enabled in production!');
      return false;
    }

    if (!EnvConfig.seedDefaultData) {
      _log('Factor seeding is disabled');
      return false;
    }

    return true;
  }

  // ==================== LOGGING HELPERS ====================

  void _log(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED_FACTORS] $message');
  }

  void _logVerbose(String message) {
    if (!EnvConfig.enableSeedingLogs || !EnvConfig.enableDebugLogs) return;
    debugPrint('[SEED_FACTORS] $message');
  }

  void _logWarning(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED_FACTORS] ⚠️  WARNING: $message');
  }

  void _logError(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED_FACTORS] ❌ ERROR: $message');
  }
}
