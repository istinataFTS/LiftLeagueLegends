import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/meal.dart';
import '../../repositories/meal_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetAllMeals {
  final MealRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetAllMeals(this.repository, {required this.sourcePreferenceResolver});

  Future<Either<Failure, List<Meal>>> call() async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getAllMeals(sourcePreference: sourcePreference);
  }
}
