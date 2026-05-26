import '../../../domain/entities/meal.dart';
import 'meal_remote_datasource.dart';

class NoopMealRemoteDataSource implements MealRemoteDataSource {
  const NoopMealRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<List<Meal>> getAllMeals() async {
    return const <Meal>[];
  }

  @override
  Future<Meal?> getMealById(String id) async {
    return null;
  }

  @override
  Future<Meal?> getMealByName(String name) async {
    return null;
  }

  @override
  Future<List<Meal>> searchMealsByName(String searchTerm) async {
    return const <Meal>[];
  }

  @override
  Future<Meal> upsertMeal(Meal meal) async {
    return meal;
  }

  @override
  Future<void> deleteMeal({required String localId, String? serverId}) async {}

  @override
  Future<List<Meal>> fetchSince({
    required String userId,
    DateTime? since,
  }) async => const <Meal>[];
}
