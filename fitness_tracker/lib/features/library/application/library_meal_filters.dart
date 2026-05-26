import '../../../domain/entities/meal.dart';

class LibraryMealFilters {
  const LibraryMealFilters._();

  static List<Meal> apply({required List<Meal> meals, required String query}) {
    final String normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return List<Meal>.from(meals, growable: false);
    }

    return meals
        .where((Meal meal) {
          return meal.name.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
  }
}
