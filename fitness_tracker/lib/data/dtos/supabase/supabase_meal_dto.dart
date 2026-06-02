import '../../../core/enums/sync_status.dart';
import '../../../core/utils/date_serialization.dart';
import '../../../domain/entities/entity_sync_metadata.dart';
import '../../../domain/entities/meal.dart';

class SupabaseMealDto {
  final String id;
  final String userId;
  final String name;
  final double servingSizeGrams;
  final double carbsPer100g;
  final double proteinPer100g;
  final double fatPer100g;
  final double caloriesPer100g;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupabaseMealDto({
    required this.id,
    required this.userId,
    required this.name,
    required this.servingSizeGrams,
    required this.carbsPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
    required this.caloriesPer100g,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupabaseMealDto.fromMap(Map<String, dynamic> map) {
    return SupabaseMealDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      servingSizeGrams: (map['serving_size_grams'] as num).toDouble(),
      carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
      proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
      fatPer100g: (map['fat_per_100g'] as num).toDouble(),
      caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
      createdAt: parseStorageDate(map['created_at'] as String),
      updatedAt: parseStorageDate(map['updated_at'] as String),
    );
  }

  factory SupabaseMealDto.fromEntity(Meal entity) {
    final ownerUserId = entity.ownerUserId;
    if (ownerUserId == null || ownerUserId.isEmpty) {
      throw ArgumentError(
        'Meal must have ownerUserId before conversion to Supabase DTO.',
      );
    }

    return SupabaseMealDto(
      id: entity.syncMetadata.serverId ?? entity.id,
      userId: ownerUserId,
      name: entity.name,
      servingSizeGrams: entity.servingSizeGrams,
      carbsPer100g: entity.carbsPer100g,
      proteinPer100g: entity.proteinPer100g,
      fatPer100g: entity.fatPer100g,
      caloriesPer100g: entity.caloriesPer100g,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Meal toEntity({
    required String localId,
    required EntitySyncMetadata syncMetadata,
  }) {
    return Meal(
      id: localId,
      ownerUserId: userId,
      name: name,
      servingSizeGrams: servingSizeGrams,
      carbsPer100g: carbsPer100g,
      proteinPer100g: proteinPer100g,
      fatPer100g: fatPer100g,
      caloriesPer100g: caloriesPer100g,
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
      'name': name,
      'serving_size_grams': servingSizeGrams,
      'carbs_per_100g': carbsPer100g,
      'protein_per_100g': proteinPer100g,
      'fat_per_100g': fatPer100g,
      'calories_per_100g': caloriesPer100g,
      'created_at': createdAt.toStorageIso(),
      'updated_at': updatedAt.toStorageIso(),
    };
  }
}
