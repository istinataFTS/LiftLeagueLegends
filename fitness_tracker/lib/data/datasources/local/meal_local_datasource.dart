import '../../models/meal_model.dart';

abstract class MealLocalDataSource {
  Future<List<MealModel>> getAllMeals();

  Future<MealModel?> getMealById(String id);

  Future<MealModel?> getMealByName(String name);

  Future<List<MealModel>> searchMealsByName(String searchTerm);

  Future<List<MealModel>> getRecentMeals({int limit = 10});

  Future<List<MealModel>> getFrequentMeals({int limit = 10});

  Future<List<MealModel>> getPendingSyncMeals();

  Future<void> insertMeal(MealModel meal);

  Future<void> updateMeal(MealModel meal);

  Future<void> upsertMeal(MealModel meal);

  /// Returns the raw stored meal row matching [name] + owner key
  /// `COALESCE(owner_user_id, '')`, bypassing the visibility filter.
  /// Used by sync to detect (name, owner) collisions before insert/update.
  Future<MealModel?> findStoredMealByNameAndOwner({
    required String name,
    required String? ownerUserId,
  });

  Future<void> prepareForInitialCloudMigration({required String userId});

  Future<void> mergeRemoteMeals(List<MealModel> meals);

  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  });

  Future<void> markAsPendingUpload(String localId, {String? errorMessage});

  Future<void> markAsPendingUpdate(String localId, {String? errorMessage});

  Future<void> markAsPendingDelete(String localId, {String? errorMessage});

  Future<void> replaceAllMeals(List<MealModel> meals);

  Future<void> deleteMeal(String id);

  Future<void> clearAllMeals();

  Future<void> clearMealsForOwner(String ownerId);

  Future<int> getMealsCount();
}
