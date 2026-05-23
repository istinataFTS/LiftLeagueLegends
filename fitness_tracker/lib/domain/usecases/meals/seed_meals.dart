import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../config/env_config.dart';
import '../../../core/constants/default_meals_data.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/deterministic_catalog_id.dart';
import '../../repositories/catalog_init_flag_repository.dart';
import '../../repositories/meal_repository.dart';

/// Seeds the default food catalog for an account if it has none yet.
///
/// Mirrors [SeedExercises]: per-account idempotent (the "already seeded"
/// check is owner-scoped via [MealRepository.getAllMeals]), and every
/// default uses a deterministic, name-derived id so the
/// `nutrition_logs.meal_id` reference never diverges across reseed / device
/// / account. User-created meals keep a v4 id via AddMeal.
class SeedMeals {
  final MealRepository repository;

  /// When provided, the per-account initialization flag is checked before
  /// querying the catalog and set after the first successful seed.  See
  /// [SeedExercises.catalogInitFlags] for the full rationale.
  final CatalogInitFlagRepository? catalogInitFlags;

  const SeedMeals(this.repository, {this.catalogInitFlags});

  /// [ownerUserId] — the account the seeded meals are owned by (the guest
  /// sentinel `''` or an authenticated uid).
  ///
  /// Returns the number of meals inserted, or 0 if seeding was skipped
  /// because the account already had meals.
  Future<Either<Failure, int>> call({String? ownerUserId}) async {
    try {
      if (!EnvConfig.seedDefaultData) {
        _log('Seeding disabled in environment config');
        return const Right(0);
      }

      // Catalog-init flag: delete-stickiness guard (mirrors SeedExercises).
      if (catalogInitFlags != null && !EnvConfig.forceReseed) {
        final initialized = await catalogInitFlags!.isInitialized(
          ownerUserId ?? '',
          'meals',
        );
        if (initialized) {
          _log(
            'Meal catalog already initialized for ${ownerUserId ?? 'guest'} — skipping',
          );
          return const Right(0);
        }
      }

      final existingResult = await repository.getAllMeals();

      return await existingResult.fold(
        (failure) async {
          _log('Failed to check existing meals: ${failure.message}');
          return Left(failure);
        },
        (existing) async {
          final hasExistingData = existing.isNotEmpty;

          if (hasExistingData && !EnvConfig.forceReseed) {
            _log('Account already has ${existing.length} meals — skipping');
            return const Right(0);
          }

          if (hasExistingData && EnvConfig.forceReseed) {
            _log('Force reseed enabled — clearing existing meals');
            await repository.clearAllMeals();
          }

          return _seedDefaultMeals(ownerUserId: ownerUserId);
        },
      );
    } catch (e) {
      return Left(DatabaseFailure('Meal seeding failed: $e'));
    }
  }

  Future<Either<Failure, int>> _seedDefaultMeals({String? ownerUserId}) async {
    final defaultMeals = DefaultMealsData.getDefaultMeals();
    final now = DateTime.now();

    int successCount = 0;
    int failureCount = 0;

    for (final mealData in defaultMeals) {
      try {
        // Owner-scoped deterministic id — see [SeedExercises] for the full
        // rationale. Without owner scoping the post-sign-in provisioning
        // step would collide on the primary key against the guest catalog
        // seeded at boot and the new user would be left with no meals.
        final meal = mealData.toEntity(
          DeterministicCatalogId.forOwner(
            ownerUserId: ownerUserId,
            name: mealData.name,
          ),
          now,
          ownerUserId: ownerUserId,
        );

        final result = await repository.addMeal(meal);
        result.fold((failure) {
          failureCount++;
          _log('Failed to seed "${meal.name}": ${failure.message}');
        }, (_) => successCount++);
      } catch (e) {
        failureCount++;
        _log('Exception seeding "${mealData.name}": $e');
      }
    }

    _log(
      'Meal seeding complete — seeded: $successCount, failed: $failureCount',
    );

    if (successCount > 0) {
      await catalogInitFlags?.markInitialized(ownerUserId ?? '', 'meals');
      return Right(successCount);
    }
    return const Left(DatabaseFailure('Failed to seed any meals'));
  }

  void _log(String message) {
    if (!EnvConfig.enableSeedingLogs) return;
    debugPrint('[SEED] $message');
  }
}
