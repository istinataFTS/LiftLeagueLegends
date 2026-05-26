import '../../../core/enums/sync_status.dart';
import '../../../domain/entities/entity_sync_metadata.dart';
import '../../../domain/entities/nutrition_log.dart';

class SupabaseNutritionLogDto {
  final String id;
  final String userId;
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

  const SupabaseNutritionLogDto({
    required this.id,
    required this.userId,
    this.mealId,
    required this.mealName,
    this.gramsConsumed,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.calories,
    required this.loggedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupabaseNutritionLogDto.fromMap(Map<String, dynamic> map) {
    return SupabaseNutritionLogDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      mealId: map['meal_id'] as String?,
      mealName: map['meal_name'] as String,
      gramsConsumed: (map['grams_consumed'] as num?)?.toDouble(),
      proteinGrams: (map['protein_grams'] as num).toDouble(),
      carbsGrams: (map['carbs_grams'] as num).toDouble(),
      fatGrams: (map['fat_grams'] as num).toDouble(),
      calories: (map['calories'] as num).toDouble(),
      loggedAt: DateTime.parse(map['logged_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory SupabaseNutritionLogDto.fromEntity(NutritionLog entity) {
    final ownerUserId = entity.ownerUserId;
    if (ownerUserId == null || ownerUserId.isEmpty) {
      throw ArgumentError(
        'NutritionLog must have ownerUserId before conversion to Supabase DTO.',
      );
    }

    return SupabaseNutritionLogDto(
      id: entity.syncMetadata.serverId ?? entity.id,
      userId: ownerUserId,
      mealId: entity.mealId,
      mealName: entity.mealName,
      gramsConsumed: entity.gramsConsumed,
      proteinGrams: entity.proteinGrams,
      carbsGrams: entity.carbsGrams,
      fatGrams: entity.fatGrams,
      calories: entity.calories,
      loggedAt: entity.loggedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  NutritionLog toEntity({
    required String localId,
    required EntitySyncMetadata syncMetadata,
  }) {
    return NutritionLog(
      id: localId,
      ownerUserId: userId,
      mealId: mealId,
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncMetadata: syncMetadata,
    );
  }

  EntitySyncMetadata toSyncedMetadata() {
    return EntitySyncMetadata(
      serverId: id,
      status: SyncStatus.synced,
      lastSyncedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'meal_id': mealId,
      'meal_name': mealName,
      'grams_consumed': gramsConsumed,
      'protein_grams': proteinGrams,
      'carbs_grams': carbsGrams,
      'fat_grams': fatGrams,
      'calories': calories,
      'logged_at': loggedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
