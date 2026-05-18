import '../../domain/entities/meal.dart';

/// Curated base food catalog seeded for every account.
///
/// These are single staple foods (not composite recipes) because the schema
/// stores macros **per 100 g** — staple foods have well-established, stable
/// per-100 g values, whereas composite "meals" vary wildly by recipe.
///
/// Calories are derived from the Atwater factors (4/4/9) so every row
/// satisfies [Meal.hasValidCalories] — there is exactly one source of truth
/// for energy and it can never drift from the macros.
///
/// A user can delete/edit/add any of these exactly like their own foods;
/// these are ordinary owned rows that merely happen to be provisioned by
/// default (see SeedMeals).
class DefaultMealsData {
  DefaultMealsData._();

  static List<MealData> getDefaultMeals() {
    return const [
      // ==================== PROTEINS — MEAT & POULTRY ====================
      MealData(name: 'Chicken Breast', carbs: 0, protein: 31, fat: 3.6),
      MealData(name: 'Chicken Thigh', carbs: 0, protein: 26, fat: 10.9),
      MealData(name: 'Ground Beef (lean)', carbs: 0, protein: 26, fat: 15),
      MealData(name: 'Beef Steak', carbs: 0, protein: 25, fat: 19),
      MealData(name: 'Pork Chop', carbs: 0, protein: 27, fat: 14),
      MealData(name: 'Turkey Breast', carbs: 0, protein: 29, fat: 1),
      MealData(name: 'Bacon', carbs: 1.4, protein: 37, fat: 42),
      MealData(name: 'Ham', carbs: 1.5, protein: 21, fat: 5),

      // ==================== PROTEINS — FISH & SEAFOOD ====================
      MealData(name: 'Salmon', carbs: 0, protein: 20, fat: 13),
      MealData(name: 'Tuna (canned in water)', carbs: 0, protein: 26, fat: 1),
      MealData(name: 'Cod', carbs: 0, protein: 18, fat: 0.7),
      MealData(name: 'Shrimp', carbs: 0.2, protein: 24, fat: 0.3),
      MealData(name: 'Tilapia', carbs: 0, protein: 26, fat: 2.7),

      // ==================== EGGS & DAIRY ====================
      MealData(name: 'Whole Egg', carbs: 1.1, protein: 13, fat: 11),
      MealData(name: 'Egg White', carbs: 0.7, protein: 11, fat: 0.2),
      MealData(name: 'Whole Milk', carbs: 4.8, protein: 3.4, fat: 3.3),
      MealData(name: 'Skim Milk', carbs: 5, protein: 3.4, fat: 0.1),
      MealData(name: 'Greek Yogurt (plain)', carbs: 3.6, protein: 10, fat: 0.4),
      MealData(name: 'Cheddar Cheese', carbs: 1.3, protein: 25, fat: 33),
      MealData(name: 'Mozzarella', carbs: 2.2, protein: 22, fat: 22),
      MealData(name: 'Cottage Cheese', carbs: 3.4, protein: 11, fat: 4.3),
      MealData(name: 'Butter', carbs: 0.1, protein: 0.9, fat: 81),

      // ==================== GRAINS & STARCHES ====================
      MealData(name: 'White Rice (cooked)', carbs: 28, protein: 2.7, fat: 0.3),
      MealData(name: 'Brown Rice (cooked)', carbs: 23, protein: 2.6, fat: 0.9),
      MealData(name: 'Pasta (cooked)', carbs: 25, protein: 5, fat: 1.1),
      MealData(name: 'White Bread', carbs: 49, protein: 9, fat: 3.2),
      MealData(name: 'Whole Wheat Bread', carbs: 43, protein: 13, fat: 3.5),
      MealData(name: 'Oats (dry)', carbs: 66, protein: 17, fat: 7),
      MealData(name: 'Quinoa (cooked)', carbs: 21, protein: 4.4, fat: 1.9),
      MealData(name: 'Potato (boiled)', carbs: 20, protein: 2, fat: 0.1),
      MealData(
        name: 'Sweet Potato (boiled)',
        carbs: 20,
        protein: 1.6,
        fat: 0.1,
      ),
      MealData(name: 'Corn', carbs: 19, protein: 3.4, fat: 1.5),

      // ==================== LEGUMES ====================
      MealData(name: 'Black Beans (cooked)', carbs: 24, protein: 9, fat: 0.5),
      MealData(name: 'Chickpeas (cooked)', carbs: 27, protein: 9, fat: 2.6),
      MealData(name: 'Lentils (cooked)', carbs: 20, protein: 9, fat: 0.4),
      MealData(name: 'Tofu', carbs: 1.9, protein: 8, fat: 4.8),
      MealData(name: 'Edamame', carbs: 8.9, protein: 11, fat: 5),

      // ==================== VEGETABLES ====================
      MealData(name: 'Broccoli', carbs: 7, protein: 2.8, fat: 0.4),
      MealData(name: 'Spinach', carbs: 3.6, protein: 2.9, fat: 0.4),
      MealData(name: 'Carrot', carbs: 10, protein: 0.9, fat: 0.2),
      MealData(name: 'Tomato', carbs: 3.9, protein: 0.9, fat: 0.2),
      MealData(name: 'Cucumber', carbs: 3.6, protein: 0.7, fat: 0.1),
      MealData(name: 'Bell Pepper', carbs: 6, protein: 1, fat: 0.3),
      MealData(name: 'Onion', carbs: 9, protein: 1.1, fat: 0.1),

      // ==================== FRUITS ====================
      MealData(name: 'Banana', carbs: 23, protein: 1.1, fat: 0.3),
      MealData(name: 'Apple', carbs: 14, protein: 0.3, fat: 0.2),
      MealData(name: 'Orange', carbs: 12, protein: 0.9, fat: 0.1),
      MealData(name: 'Strawberries', carbs: 7.7, protein: 0.7, fat: 0.3),
      MealData(name: 'Blueberries', carbs: 14, protein: 0.7, fat: 0.3),
      MealData(name: 'Avocado', carbs: 9, protein: 2, fat: 15),

      // ==================== NUTS & FATS ====================
      MealData(name: 'Almonds', carbs: 22, protein: 21, fat: 49),
      MealData(name: 'Peanut Butter', carbs: 20, protein: 25, fat: 50),
      MealData(name: 'Olive Oil', carbs: 0, protein: 0, fat: 100),
    ];
  }

  static int get mealsCount => getDefaultMeals().length;
}

/// Lightweight seed record for a default food.
///
/// [caloriesPer100g] is intentionally derived (Atwater 4/4/9) rather than
/// stored, so the energy value can never disagree with the macros.
class MealData {
  const MealData({
    required this.name,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.servingSizeGrams = 100.0,
  });

  final String name;
  final double carbs;
  final double protein;
  final double fat;
  final double servingSizeGrams;

  double get caloriesPer100g => (carbs * 4.0) + (protein * 4.0) + (fat * 9.0);

  Meal toEntity(String id, DateTime createdAt, {String? ownerUserId}) {
    return Meal(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      servingSizeGrams: servingSizeGrams,
      carbsPer100g: carbs,
      proteinPer100g: protein,
      fatPer100g: fat,
      caloriesPer100g: caloriesPer100g,
      createdAt: createdAt,
    );
  }
}
