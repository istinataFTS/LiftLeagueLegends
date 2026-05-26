import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/meal.dart';
import '../../repositories/meal_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetMealById {
  final MealRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetMealById(this.repository, {required this.sourcePreferenceResolver});

  Future<Either<Failure, Meal?>> call(String id) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getMealById(id, sourcePreference: sourcePreference);
  }
}
