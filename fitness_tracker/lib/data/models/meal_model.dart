import '../../core/constants/database_tables.dart';
import '../../core/enums/sync_status.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/macro_calculator.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/meal.dart';

class MealModel extends Meal {
  const MealModel({
    required super.id,
    super.ownerUserId,
    required super.name,
    required super.servingSizeGrams,
    required super.carbsPer100g,
    required super.proteinPer100g,
    required super.fatPer100g,
    required super.caloriesPer100g,
    required super.createdAt,
    super.updatedAt,
    super.syncMetadata,
  });

  factory MealModel.fromEntity(Meal meal) {
    return MealModel(
      id: meal.id,
      ownerUserId: meal.ownerUserId,
      name: meal.name,
      servingSizeGrams: meal.servingSizeGrams,
      carbsPer100g: meal.carbsPer100g,
      proteinPer100g: meal.proteinPer100g,
      fatPer100g: meal.fatPer100g,
      caloriesPer100g: meal.caloriesPer100g,
      createdAt: meal.createdAt,
      updatedAt: meal.updatedAt,
      syncMetadata: meal.syncMetadata,
    );
  }

  factory MealModel.fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.parse(
      map[DatabaseTables.mealCreatedAt] as String,
    );
    final updatedAtRaw = map[DatabaseTables.mealUpdatedAt] as String?;

    return MealModel(
      id: map[DatabaseTables.mealId] as String,
      ownerUserId: map['owner_user_id'] as String?,
      name: map[DatabaseTables.mealName] as String,
      servingSizeGrams: (map[DatabaseTables.mealServingSize] as num).toDouble(),
      carbsPer100g: (map[DatabaseTables.mealCarbsPer100g] as num).toDouble(),
      proteinPer100g: (map[DatabaseTables.mealProteinPer100g] as num)
          .toDouble(),
      fatPer100g: (map[DatabaseTables.mealFatPer100g] as num).toDouble(),
      caloriesPer100g: (map[DatabaseTables.mealCaloriesPer100g] as num)
          .toDouble(),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null
          ? createdAt
          : DateTime.parse(updatedAtRaw),
      syncMetadata: EntitySyncMetadata(
        serverId: map[DatabaseTables.mealServerId] as String?,
        status: _syncStatusFromStorage(
          map[DatabaseTables.mealSyncStatus] as String?,
        ),
        lastSyncedAt: _parseNullableDateTime(
          map[DatabaseTables.mealLastSyncedAt] as String?,
        ),
        lastSyncError: map[DatabaseTables.mealLastSyncError] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.mealId: id,
      'owner_user_id': ownerUserId,
      DatabaseTables.mealName: name,
      DatabaseTables.mealServingSize: servingSizeGrams,
      DatabaseTables.mealCarbsPer100g: carbsPer100g,
      DatabaseTables.mealProteinPer100g: proteinPer100g,
      DatabaseTables.mealFatPer100g: fatPer100g,
      DatabaseTables.mealCaloriesPer100g: caloriesPer100g,
      DatabaseTables.mealCreatedAt: createdAt.toIso8601String(),
      DatabaseTables.mealUpdatedAt: updatedAt.toIso8601String(),
      DatabaseTables.mealServerId: syncMetadata.serverId,
      DatabaseTables.mealSyncStatus: syncMetadata.status.name,
      DatabaseTables.mealLastSyncedAt: syncMetadata.lastSyncedAt
          ?.toIso8601String(),
      DatabaseTables.mealLastSyncError: syncMetadata.lastSyncError,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'name': name,
      'servingSizeGrams': servingSizeGrams,
      'carbsPer100g': carbsPer100g,
      'proteinPer100g': proteinPer100g,
      'fatPer100g': fatPer100g,
      'caloriesPer100g': caloriesPer100g,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'serverId': syncMetadata.serverId,
      'syncStatus': syncMetadata.status.name,
      'lastSyncedAt': syncMetadata.lastSyncedAt?.toIso8601String(),
      'lastSyncError': syncMetadata.lastSyncError,
    };
  }

  bool get hasValidCalories {
    final calculated = calculatedCalories;
    const tolerance = 5.0;
    return (caloriesPer100g - calculated).abs() <= tolerance;
  }

  @override
  double get calculatedCalories {
    return MacroCalculator.calculateCalories(
      carbs: carbsPer100g,
      protein: proteinPer100g,
      fat: fatPer100g,
    );
  }

  void validateMacros() {
    if (name.trim().isEmpty) {
      throw ArgumentError('Meal name cannot be empty');
    }

    if (servingSizeGrams <= 0) {
      throw ArgumentError('Serving size must be greater than 0');
    }

    if (carbsPer100g < 0 || proteinPer100g < 0 || fatPer100g < 0) {
      throw ArgumentError('Macros cannot be negative');
    }

    if (caloriesPer100g < 0) {
      throw ArgumentError('Calories cannot be negative');
    }
  }

  void validateAndLogCalories() {
    if (!hasValidCalories) {
      final calculated = calculatedCalories;
      AppLogger.warning(
        'Meal "$name" calorie mismatch: '
        'stated $caloriesPer100g cal, '
        'calculated ${calculated.toStringAsFixed(1)} cal from macros '
        '(diff: ${(caloriesPer100g - calculated).abs().toStringAsFixed(1)} cal)',
        category: 'nutrition',
      );
    }
  }

  @override
  MealModel copyWith({
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
    return MealModel(
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

  factory MealModel.withCalculatedMacros({
    required String id,
    String? ownerUserId,
    required String name,
    double servingSizeGrams = 100,
    double? carbsPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? caloriesPer100g,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) {
    if (caloriesPer100g != null) {
      if (carbsPer100g == null &&
          proteinPer100g != null &&
          fatPer100g != null) {
        carbsPer100g = MacroCalculator.calculateCarbsFromCalories(
          totalCalories: caloriesPer100g,
          protein: proteinPer100g,
          fat: fatPer100g,
        );
      }

      if (proteinPer100g == null &&
          carbsPer100g != null &&
          fatPer100g != null) {
        proteinPer100g = MacroCalculator.calculateProteinFromCalories(
          totalCalories: caloriesPer100g,
          carbs: carbsPer100g,
          fat: fatPer100g,
        );
      }

      if (fatPer100g == null &&
          carbsPer100g != null &&
          proteinPer100g != null) {
        fatPer100g = MacroCalculator.calculateFatFromCalories(
          totalCalories: caloriesPer100g,
          carbs: carbsPer100g,
          protein: proteinPer100g,
        );
      }
    }

    final finalCalories =
        caloriesPer100g ??
        MacroCalculator.calculateCalories(
          carbs: carbsPer100g ?? 0,
          protein: proteinPer100g ?? 0,
          fat: fatPer100g ?? 0,
        );

    final effectiveCreatedAt = createdAt ?? DateTime.now();

    return MealModel(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      servingSizeGrams: servingSizeGrams,
      carbsPer100g: carbsPer100g ?? 0,
      proteinPer100g: proteinPer100g ?? 0,
      fatPer100g: fatPer100g ?? 0,
      caloriesPer100g: finalCalories,
      createdAt: effectiveCreatedAt,
      updatedAt: updatedAt ?? effectiveCreatedAt,
      syncMetadata: syncMetadata,
    );
  }

  static DateTime? _parseNullableDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    return DateTime.parse(value);
  }

  static SyncStatus _syncStatusFromStorage(String? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.localOnly,
    );
  }
}
