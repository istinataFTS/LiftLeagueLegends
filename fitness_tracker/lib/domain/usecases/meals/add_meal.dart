import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/meal.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/meal_repository.dart';

class AddMeal {
  final MealRepository repository;
  final AppSessionRepository appSessionRepository;

  const AddMeal(this.repository, {required this.appSessionRepository});

  Future<Either<Failure, void>> call(Meal meal) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    return sessionResult.fold(
      (failure) => Left(failure),
      (session) =>
          repository.addMeal(meal.copyWith(ownerUserId: session.user.id)),
    );
  }
}
