import 'package:flutter/foundation.dart' show debugPrint;

import '../../config/env_config.dart';
import '../../core/session/current_user_id_resolver.dart';
import '../../data/datasources/local/app_metadata_local_datasource.dart';
import '../../domain/repositories/app_session_repository.dart';
import '../../domain/usecases/exercises/seed_exercises.dart';
import '../../domain/usecases/meals/seed_meals.dart';
import '../../domain/usecases/muscle_factors/seed_exercise_factors.dart';
import '../../domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import '../../injection/injection_container.dart' as di;

/// Coordinates startup data population.
///
/// There are two distinct responsibilities here, intentionally kept
/// separate so that flipping `seedDefaultData` off in a production-like
/// build does not silently disable the domain-data heal path:
///
/// 1. **Demo-data seeding** — exercises + their muscle factors.  Gated by
///    [EnvConfig.seedDefaultData] because users in a production flow may
///    want to start from a blank exercise library.
/// 2. **Muscle-factor healing** — always runs.  Factors are biomechanical
///    *domain data*, not demo content; if the table is empty we re-seed it
///    from [ExerciseMuscleFactorsData] so the 2D muscle map and fatigue
///    calculations keep working.  When factors actually get written, we
///    also rebuild muscle stimulus from workout history so past sets show
///    up in the map immediately.
class AppDataSeeder {
  const AppDataSeeder();

  Future<void> seedIfEnabled() async {
    if (EnvConfig.seedDefaultData) {
      await _seedDemoData();
    } else {
      debugPrint(
        'Demo-data seeding disabled (EnvConfig.seedDefaultData=false)',
      );
    }

    // Always run the heal step — factors are domain data, not demo data.
    // Safe no-op when all exercises already have factors: the underlying use
    // case performs a single getAllFactors() query and only inserts rows for
    // exercises that currently have none (per-exercise idempotency).
    await _healMuscleFactorsIfMissing();

    // One-time fix: stimulus rows written before the set-date bug fix were
    // stamped with today's date instead of the set's actual date.  Run a
    // full rebuild once, then set the flag so this never runs again.
    await _healStimulusDatesIfNeeded();
  }

  Future<void> _seedDemoData() async {
    debugPrint('Seeding database...');
    final seedStart = DateTime.now();

    // Per-user catalog model: seed for the active account — the guest
    // sentinel '' on a fresh launch, or a restored authenticated uid. The
    // resolved owner is exactly the owner SeedExercises' owner-scoped
    // "already seeded" check evaluates against, so the check and the stamp
    // always agree and seeding stays per-account idempotent.
    final resolver = CurrentUserIdResolver(
      appSessionRepository: di.sl<AppSessionRepository>(),
    );
    final ownerId = await resolver.resolve();

    final seedMeals = di.sl<SeedMeals>();
    final mealsResult = await seedMeals(ownerUserId: ownerId);
    mealsResult.fold(
      (failure) => debugPrint('⚠️ Meal seeding failed: ${failure.message}'),
      (mealCount) {
        if (mealCount > 0) {
          debugPrint('✅ Seeded $mealCount meals');
        }
      },
    );

    final seedExercises = di.sl<SeedExercises>();
    final exercisesResult = await seedExercises(ownerUserId: ownerId);

    await exercisesResult.fold(
      (failure) async {
        debugPrint('⚠️ Exercise seeding failed: ${failure.message}');
      },
      (exerciseCount) async {
        final exerciseDuration = DateTime.now().difference(seedStart);
        debugPrint(
          '✅ Seeded $exerciseCount exercises in: ${exerciseDuration.inMilliseconds}ms',
        );

        final factorSeedStart = DateTime.now();
        final seedFactors = di.sl<SeedExerciseFactors>();
        final factorsResult = await seedFactors();

        await factorsResult.fold(
          (failure) async {
            debugPrint('⚠️ Muscle factor seeding failed: ${failure.message}');
          },
          (factorCount) async {
            final factorDuration = DateTime.now().difference(factorSeedStart);
            debugPrint(
              '✅ Seeded $factorCount muscle factors in: ${factorDuration.inMilliseconds}ms',
            );

            if (factorCount > 0) {
              // Factors were freshly seeded (DB migration cleared the old
              // ones).  Rebuild muscle stimulus history so past workout
              // sets are reflected in the fatigue map and weekly targets
              // immediately on first launch.
              await _rebuildStimulus();
            }
          },
        );
      },
    );

    final totalSeedDuration = DateTime.now().difference(seedStart);
    debugPrint(
      '✅ Database seeding completed in: ${totalSeedDuration.inMilliseconds}ms',
    );
  }

  /// Re-runs [SeedExerciseFactors] with the healing flag.
  ///
  /// The use case itself checks whether the factor table is empty before
  /// writing, so this is a cheap no-op when everything is healthy.  We do
  /// pay one `getAllFactors` query on every launch — acceptable given the
  /// table is tiny and the bug we are protecting against (silent empty-map
  /// fatigue view) is user-visible.
  Future<void> _healMuscleFactorsIfMissing() async {
    final healStart = DateTime.now();
    final seedFactors = di.sl<SeedExerciseFactors>();
    final healResult = await seedFactors(allowHealingWhenEmpty: true);

    await healResult.fold(
      (failure) async {
        debugPrint('⚠️ Muscle factor heal failed: ${failure.message}');
      },
      (factorCount) async {
        if (factorCount <= 0) {
          // Either already populated (healthy) or use case returned 0 for
          // another benign reason.  Nothing to do.
          return;
        }

        final healDuration = DateTime.now().difference(healStart);
        debugPrint(
          '🩹 Healed $factorCount muscle factors in: ${healDuration.inMilliseconds}ms',
        );
        await _rebuildStimulus();
      },
    );
  }

  Future<void> _healStimulusDatesIfNeeded() async {
    // v2 bump: re-runs the rebuild so any pre-existing stimulus rows derived
    // from now-orphaned WorkoutSets (deleted exercises) — which the rebuild
    // skips because their factor lookup returns empty — get cleared and the
    // muscle map stops painting muscles that have no resolvable training
    // behind them.
    const flagKey = 'stimulus_set_date_fix_v2';
    final metadata = di.sl<AppMetadataLocalDataSource>();

    final alreadyApplied = await metadata.readBool(flagKey);
    if (alreadyApplied == true) return;

    debugPrint('🩹 Applying one-time stimulus rebuild (date + orphan fix)...');
    await _rebuildStimulus();
    await metadata.writeBool(flagKey, true);
    debugPrint('✅ Stimulus rebuild applied and flagged.');
  }

  Future<void> _rebuildStimulus() async {
    debugPrint('🔄 Rebuilding muscle stimulus from workout history...');
    final rebuildStart = DateTime.now();

    // Use the shared resolver so the id we rebuild against matches the id
    // used on write paths (WorkoutBloc / AddExercise) and read paths
    // (MuscleVisualBloc).  Guest sessions resolve to [kGuestUserId].
    final resolver = CurrentUserIdResolver(
      appSessionRepository: di.sl<AppSessionRepository>(),
    );
    final userId = await resolver.resolve();

    final rebuild = di.sl<RebuildMuscleStimulusFromWorkoutHistory>();
    final rebuildResult = await rebuild(userId);
    final rebuildDuration = DateTime.now().difference(rebuildStart);

    rebuildResult.fold(
      (failure) {
        debugPrint('⚠️ Muscle stimulus rebuild failed: ${failure.message}');
      },
      (_) {
        debugPrint(
          '✅ Muscle stimulus rebuilt in: ${rebuildDuration.inMilliseconds}ms',
        );
      },
    );
  }
}
