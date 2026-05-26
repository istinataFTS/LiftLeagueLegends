import '../../../domain/entities/meal.dart';

abstract class MealRemoteDataSource {
  bool get isConfigured;

  Future<List<Meal>> getAllMeals();

  Future<Meal?> getMealById(String id);

  Future<Meal?> getMealByName(String name);

  Future<List<Meal>> searchMealsByName(String searchTerm);

  Future<Meal> upsertMeal(Meal meal);

  Future<void> deleteMeal({required String localId, String? serverId});

  /// Returns all meals for [userId] whose `updated_at` is after [since].
  /// Pass [since] = null to fetch all meals (e.g. on initial re-login).
  Future<List<Meal>> fetchSince({required String userId, DateTime? since});
}
