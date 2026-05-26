import 'package:equatable/equatable.dart';

import 'entity_sync_metadata.dart';

class NutritionLog extends Equatable {
  final String id;
  final String? ownerUserId;
  final String? mealId;
  final String mealName;
  final double? gramsConsumed;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double calories;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntitySyncMetadata syncMetadata;

  const NutritionLog({
    required this.id,
    this.ownerUserId,
    this.mealId,
    required this.mealName,
    this.gramsConsumed,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.calories,
    required this.loggedAt,
    required this.createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) : updatedAt = updatedAt ?? createdAt,
       syncMetadata = syncMetadata ?? const EntitySyncMetadata();

  bool get isOwnedByAuthenticatedUser => ownerUserId != null;
  bool get isMealLog => mealId != null;
  bool get isDirectMacroLog => mealId == null;

  double get calculatedCalories {
    return (carbsGrams * 4.0) + (proteinGrams * 4.0) + (fatGrams * 9.0);
  }

  bool get hasValidCalories {
    return (calories - calculatedCalories).abs() <= 1.0;
  }

  bool get isValidMealLog {
    return mealId != null && gramsConsumed != null && gramsConsumed! > 0;
  }

  bool get isValidDirectMacroLog {
    return mealId == null &&
        (carbsGrams > 0 || proteinGrams > 0 || fatGrams > 0);
  }

  NutritionLog copyWith({
    String? id,
    String? ownerUserId,
    bool clearOwnerUserId = false,
    String? mealId,
    String? mealName,
    double? gramsConsumed,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    double? calories,
    DateTime? loggedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) {
    return NutritionLog(
      id: id ?? this.id,
      ownerUserId: clearOwnerUserId ? null : (ownerUserId ?? this.ownerUserId),
      mealId: mealId ?? this.mealId,
      mealName: mealName ?? this.mealName,
      gramsConsumed: gramsConsumed ?? this.gramsConsumed,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      calories: calories ?? this.calories,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerUserId,
    mealId,
    mealName,
    gramsConsumed,
    proteinGrams,
    carbsGrams,
    fatGrams,
    calories,
    loggedAt,
    createdAt,
    updatedAt,
    syncMetadata,
  ];
}
