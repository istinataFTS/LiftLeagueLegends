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

    return sessionResult.fold((failure) => Left(failure), (session) {
      final userId = session.user.id;
      final preparedMeal = meal.ownerUserId == userId
          ? meal
          : meal.copyWith(ownerUserId: userId);
      return repository.updateMeal(preparedMeal);
    });
  }
}
