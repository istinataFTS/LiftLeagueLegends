import 'package:equatable/equatable.dart';

import 'entity_sync_metadata.dart';

class Meal extends Equatable {
  final String id;
  final String? ownerUserId;
  final String name;
  final double servingSizeGrams;
  final double carbsPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double caloriesPer100g;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntitySyncMetadata syncMetadata;

  const Meal({
    required this.id,
    this.ownerUserId,
    required this.name,
    required this.servingSizeGrams,
    required this.carbsPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.caloriesPer100g,
    required this.createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) : updatedAt = updatedAt ?? createdAt,
       syncMetadata = syncMetadata ?? const EntitySyncMetadata();

  bool get isOwnedByAuthenticatedUser => ownerUserId != null;

  double get proteinPerServing => (proteinPer100g * servingSizeGrams) / 100;
  double get carbsPerServing => (carbsPer100g * servingSizeGrams) / 100;
  double get fatsPerServing => (fatPer100g * servingSizeGrams) / 100;
  double get caloriesPerServing => (caloriesPer100g * servingSizeGrams) / 100;

  double get calculatedCalories {
    return (carbsPer100g * 4.0) + (proteinPer100g * 4.0) + (fatPer100g * 9.0);
  }

  bool get hasValidCalories {
    return (caloriesPer100g - calculatedCalories).abs() <= 1.0;
  }

  MealNutrition calculateForGrams(double grams) {
    final multiplier = grams / 100.0;
    return MealNutrition(
      carbs: carbsPer100g * multiplier,
      protein: proteinPer100g * multiplier,
      fat: fatPer100g * multiplier,
      calories: caloriesPer100g * multiplier,
      grams: grams,
    );
  }

  Meal copyWith({
    String? id,
    String? ownerUserId,
    bool clearOwnerUserId = false,
    String? name,
    double? servingSizeGrams,
    double? carbsPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? caloriesPer100g,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) {
    return Meal(
      id: id ?? this.id,
      ownerUserId: clearOwnerUserId ? null : (ownerUserId ?? this.ownerUserId),
      name: name ?? this.name,
      servingSizeGrams: servingSizeGrams ?? this.servingSizeGrams,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerUserId,
    name,
    servingSizeGrams,
    carbsPer100g,
    proteinPer100g,
    fatPer100g,
    caloriesPer100g,
    createdAt,
    updatedAt,
    syncMetadata,
  ];
}

class MealNutrition {
  final double carbs;
  final double protein;
  final double fat;
  final double calories;
  final double grams;

  const MealNutrition({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.calories,
    required this.grams,
  });
}
