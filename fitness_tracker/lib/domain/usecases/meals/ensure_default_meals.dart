import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/app_session_repository.dart';
import 'seed_meals.dart';

/// Per-user safety-net that guarantees the current account always has the
/// default food catalog available.
///
/// The counterpart to [EnsureDefaultExercises]: called by [MealBloc] when a
/// successful load returns an empty list (fresh device, second user on a
/// shared device, cloud account with no meals). [SeedMeals] is owner-scoped
/// and idempotent, so this is a cheap no-op once the account has meals.
class EnsureDefaultMeals {
  const EnsureDefaultMeals({
    required this.appSessionRepository,
    required this.seedMeals,
  });

  final AppSessionRepository appSessionRepository;
  final SeedMeals seedMeals;

  /// Returns the number of meals seeded (0 when the account already had
  /// meals and no action was taken).
  Future<Either<Failure, int>> call() async {
    try {
      final sessionResult = await appSessionRepository.getCurrentSession();
      final String? userId = sessionResult.fold(
        (_) => null,
        (session) => session.user?.id,
      );

      return await seedMeals(ownerUserId: userId);
    } catch (e, stackTrace) {
      debugPrint('[EnsureDefaultMeals] Unexpected error: $e\n$stackTrace');
      return Left(DatabaseFailure('EnsureDefaultMeals failed: $e'));
    }
  }
}
