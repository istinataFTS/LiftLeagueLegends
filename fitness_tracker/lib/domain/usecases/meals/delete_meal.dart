import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/meal_repository.dart';

class DeleteMeal {
  final MealRepository repository;

  const DeleteMeal(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteMeal(id);
  }
}
