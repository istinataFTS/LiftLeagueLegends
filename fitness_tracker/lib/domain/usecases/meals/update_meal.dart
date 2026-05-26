import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/meal.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/meal_repository.dart';

class UpdateMeal {
  final MealRepository repository;
  final AppSessionRepository appSessionRepository;

  const UpdateMeal(this.repository, {required this.appSessionRepository});

  Future<Either<Failure, void>> call(Meal meal) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    final preparedMeal = sessionResult.fold((_) => meal, (session) {
      if (!session.isAuthenticated || session.user == null) {
        return meal;
      }

      if (meal.ownerUserId == session.user!.id) {
        return meal;
      }

      return meal.copyWith(ownerUserId: session.user!.id);
    });

    return repository.updateMeal(preparedMeal);
  }
}
