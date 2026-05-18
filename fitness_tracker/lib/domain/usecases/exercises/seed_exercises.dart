import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../config/env_config.dart';
import '../../../core/constants/default_exercises_data.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/deterministic_catalog_id.dart';
import '../../repositories/catalog_init_flag_repository.dart';
import '../../repositories/exercise_repository.dart';

class SeedExercises {
  final ExerciseRepository repository;

  /// When provided, the per-account initialization flag is checked before
  /// querying the catalog and set after the first successful seed.  This
  /// enforces the delete-stickiness invariant: a user who deliberately deletes
  /// every default exercise will not have them resurrected on the next launch
  /// or sync (the flag remains set, so seeding is skipped even when the
  /// catalog is empty).  Pass null in tests that do not need the flag.
  final CatalogInitFlagRepository? catalogInitFlags;

  const SeedExercises(this.repository, {this.catalogInitFlags});

  /// Seeds default exercises if none exist yet.
  ///
  /// [ownerUserId] — when provided the seeded exercises are owned by that
  /// user (per-user seeding). When omitted the exercises are created as
  /// system/shared exercises (owner_user_id IS NULL), visible to all users.
  ///
  /// Returns the number of exercises actually inserted, or 0 if seeding was
  /// skipped because exercises already existed.
  Future<Either<Failure, int>> call({String? ownerUserId}) async {
    try {
      // Step 1: Check if seeding is enabled
      if (!EnvConfig.seedDefaultData) {
        _log('Seeding disabled in environment config');
        return const Right(0);
      }

      _log('Starting database seeding process...');
      _log('Seed data version: ${EnvConfig.seedDataVersion}');
      if (ownerUserId != null) {
        _log('Seeding as user-owned exercises (userId: $ownerUserId)');
      }

      // Step 2a: Check catalog-init flag (delete-stickiness guard).
      // If the flag is already set the account previously received its default
      // catalog; honour any subsequent deletions by not re-seeding even when
      // the catalog is currently empty.  forceReseed bypasses this guard.
      if (catalogInitFlags != null && !EnvConfig.forceReseed) {
        final initialized = await catalogInitFlags!.isInitialized(
          ownerUserId ?? '',
          'exercises',
        );
        if (initialized) {
          _log(
            'Catalog already initialized for ${ownerUserId ?? 'guest'} — skipping',
          );
          return const Right(0);
        }
      }

      // Step 2b: Check if database already has exercises
      final existingExercisesResult = await repository.getAllExercises();

      return await existingExercisesResult.fold(
        // Error getting existing exercises
        (failure) async {
          _logError('Failed to check existing exercises: ${failure.message}');
          return Left(failure);
        },
        // Successfully got existing exercises
        (existingExercises) async {
          final hasExistingData = existingExercises.isNotEmpty;

          // Step 3: Decide if we should seed
          if (hasExistingData && !EnvConfig.forceReseed) {
            _log('Database already has ${existingExercises.length} exercises');
            _log('Skipping seeding (set FORCE_RESEED=true to override)');
            return const Right(0);
          }

          if (hasExistingData && EnvConfig.forceReseed) {
            _logWarning('Force reseed enabled - clearing existing data');
            // Note: In production, you might want to backup data first
            await _clearExistingData();
          }

          // Step 4: Perform seeding
          return await _seedDefaultExercises(ownerUserId: ownerUserId);
        },
      );
    } catch (e) {
      _logError('Unexpected error during seeding: $e');
      return Left(DatabaseFailure('Seeding failed: $e'));
    }
  }

  /// Clear existing exercise data (used with force reseed)
  Future<void> _clearExistingData() async {
    _log('Clearing existing exercise data...');

    try {
      await repository.clearAllExercises();
      _log('Successfully cleared existing data');
    } catch (e) {
      _logError('Failed to clear existing data: $e');
      rethrow;
    }
  }

  /// Seed all default exercises.
  ///
  /// [ownerUserId] is forwarded to [ExerciseData.toEntity] so each inserted
  /// exercise can be owned by a specific user or kept as a shared system
  /// exercise (null).
  Future<Either<Failure, int>> _seedDefaultExercises({
    String? ownerUserId,
  }) async {
    _log('Seeding default exercises...');

    final defaultExercises = DefaultExercisesData.getDefaultExercises();
    _log('Total exercises to seed: ${defaultExercises.length}');

    int successCount = 0;
    int failureCount = 0;
    final now = DateTime.now();

    // Seed exercises one by one
    // Note: In a production app, you might want to use batch insert
    for (final exerciseData in defaultExercises) {
      try {
        // Deterministic, name-derived id: stable across every device,
        // reseed and account, so the workout_sets→exercise reference never
        // diverges (the root cause of the sign-in failure / "Unknown
        // exercise"). User-created exercises still get a v4 id via
        // AddExercise — only the curated defaults are deterministic.
        final exercise = exerciseData.toEntity(
          DeterministicCatalogId.fromName(exerciseData.name),
          now,
          ownerUserId: ownerUserId,
        );

        final result = await repository.addExercise(exercise);

        result.fold(
          (failure) {
            failureCount++;
            _logError('Failed to seed "${exercise.name}": ${failure.message}');
          },
          (_) {
            successCount++;
            _logVerbose('✓ Seeded: ${exercise.name}');
          },
        );
      } catch (e) {
        failureCount++;
        _logError('Exception seeding "${exerciseData.name}": $e');
      }
    }

    // Step 5: Log results
    _log('========== Seeding Complete ==========');
    _log('Successfully seeded: $successCount exercises');
    if (failureCount > 0) {
      _logWarning('Failed to seed: $failureCount exercises');
    }
    _log('======================================');

    // Return success if at least some exercises were seeded
    if (successCount > 0) {
      await catalogInitFlags?.markInitialized(ownerUserId ?? '', 'exercises');
      return Right(successCount);
    } else {
      return const Left(DatabaseFailure('Failed to seed any exercises'));
    }
  }

  /// Validate seeding environment (optional pre-check)
  bool validateEnvironment() {
    if (EnvConfig.isProduction && EnvConfig.forceReseed) {
      _logError('CRITICAL: Force reseed enabled in production!');
      return false;
    }

    if (!EnvConfig.seedDefaultData) {
      _log('Seeding is disabled');
      return false;
    }

    return true;
  }

  // ==================== Logging Helpers ====================

  void _log(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED] $message');
  }

  void _logVerbose(String message) {
    if (!EnvConfig.enableSeedingLogs || !EnvConfig.enableDebugLogs) return;
    debugPrint('[SEED] $message');
  }

  void _logWarning(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED] ⚠️  WARNING: $message');
  }

  void _logError(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED] ❌ ERROR: $message');
  }
}
