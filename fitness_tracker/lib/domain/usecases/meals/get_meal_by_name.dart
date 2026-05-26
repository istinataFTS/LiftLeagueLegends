import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/meal.dart';
import '../../repositories/meal_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetMealByName {
  final MealRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetMealByName(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, Meal?>> call(String name) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getMealByName(name, sourcePreference: sourcePreference);
  }
}
