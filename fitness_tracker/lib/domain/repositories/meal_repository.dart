import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../entities/meal.dart';

abstract class MealRepository {
  Future<Either<Failure, List<Meal>>> getAllMeals({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, Meal?>> getMealById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, Meal?>> getMealByName(
    String name, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<Meal>>> searchMealsByName(
    String query, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<Meal>>> getRecentMeals({
    int limit = 5,
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<Meal>>> getFrequentMeals({
    int limit = 10,
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, void>> addMeal(Meal meal);

  Future<Either<Failure, void>> updateMeal(Meal meal);

  Future<Either<Failure, void>> deleteMeal(String id);

  Future<Either<Failure, void>> clearAllMeals();

  Future<Either<Failure, int>> getMealsCount();

  Future<Either<Failure, void>> syncPendingMeals();
}
