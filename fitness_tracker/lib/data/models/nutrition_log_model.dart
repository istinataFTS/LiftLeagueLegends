import '../../core/constants/database_tables.dart';
import '../../core/enums/sync_status.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/date_serialization.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/nutrition_log.dart';

class NutritionLogModel extends NutritionLog {
  const NutritionLogModel({
    required super.id,
    super.ownerUserId,
    super.mealId,
    required super.mealName,
    super.gramsConsumed,
    required super.proteinGrams,
    required super.carbsGrams,
    required super.fatGrams,
    required super.calories,
    required super.loggedAt,
    required super.createdAt,
    super.updatedAt,
    super.syncMetadata,
  });

  factory NutritionLogModel.fromEntity(NutritionLog log) {
    return NutritionLogModel(
      id: log.id,
      ownerUserId: log.ownerUserId,
      mealId: log.mealId,
      mealName: log.mealName,
      gramsConsumed: log.gramsConsumed,
      proteinGrams: log.proteinGrams,
      carbsGrams: log.carbsGrams,
      fatGrams: log.fatGrams,
      calories: log.calories,
      loggedAt: log.loggedAt,
      createdAt: log.createdAt,
      updatedAt: log.updatedAt,
      syncMetadata: log.syncMetadata,
    );
  }

  factory NutritionLogModel.fromMap(Map<String, dynamic> map) {
    final createdAt = parseStorageDate(
      map[DatabaseTables.nutritionLogCreatedAt] as String,
    );
    final updatedAtRaw = map[DatabaseTables.nutritionLogUpdatedAt] as String?;

    return NutritionLogModel(
      id: map[DatabaseTables.nutritionLogId] as String,
      ownerUserId: map['owner_user_id'] as String?,
      mealId: map[DatabaseTables.nutritionLogMealId] as String?,
      mealName: map[DatabaseTables.nutritionLogMealName] as String,
      gramsConsumed: (map[DatabaseTables.nutritionLogGrams] as num?)
          ?.toDouble(),
      proteinGrams: (map[DatabaseTables.nutritionLogProtein] as num).toDouble(),
      carbsGrams: (map[DatabaseTables.nutritionLogCarbs] as num).toDouble(),
      fatGrams: (map[DatabaseTables.nutritionLogFat] as num).toDouble(),
      calories: (map[DatabaseTables.nutritionLogCalories] as num).toDouble(),
      loggedAt: parseStorageDate(
        map[DatabaseTables.nutritionLogDate] as String,
      ),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null
          ? createdAt
          : parseStorageDate(updatedAtRaw),
      syncMetadata: EntitySyncMetadata(
        serverId: map[DatabaseTables.nutritionLogServerId] as String?,
        status: _syncStatusFromStorage(
          map[DatabaseTables.nutritionLogSyncStatus] as String?,
        ),
        lastSyncedAt: parseStorageDateOrNull(
          map[DatabaseTables.nutritionLogLastSyncedAt] as String?,
        ),
        lastSyncError: map[DatabaseTables.nutritionLogLastSyncError] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.nutritionLogId: id,
      'owner_user_id': ownerUserId,
      DatabaseTables.nutritionLogMealId: mealId,
      DatabaseTables.nutritionLogMealName: mealName,
      DatabaseTables.nutritionLogGrams: gramsConsumed,
      DatabaseTables.nutritionLogProtein: proteinGrams,
      DatabaseTables.nutritionLogCarbs: carbsGrams,
      DatabaseTables.nutritionLogFat: fatGrams,
      DatabaseTables.nutritionLogCalories: calories,
      DatabaseTables.nutritionLogDate: loggedAt.toStorageIso(),
      DatabaseTables.nutritionLogCreatedAt: createdAt.toStorageIso(),
      DatabaseTables.nutritionLogUpdatedAt: updatedAt.toStorageIso(),
      DatabaseTables.nutritionLogServerId: syncMetadata.serverId,
      DatabaseTables.nutritionLogSyncStatus: syncMetadata.status.name,
      DatabaseTables.nutritionLogLastSyncedAt: syncMetadata.lastSyncedAt
          ?.toStorageIso(),
      DatabaseTables.nutritionLogLastSyncError: syncMetadata.lastSyncError,
    };
  }

  /// JSON serialization for future API / debugging use.
  ///
  /// **Not currently called** — local persistence uses [toMap] (DB column
  /// names) and remote sync uses `SupabaseNutritionLogDto`. Kept for
  /// completeness; keys use camelCase per JSON convention.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'mealId': mealId,
      'mealName': mealName,
      'gramsConsumed': gramsConsumed,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'calories': calories,
      'loggedAt': loggedAt.toStorageIso(),
      'createdAt': createdAt.toStorageIso(),
      'updatedAt': updatedAt.toStorageIso(),
      'serverId': syncMetadata.serverId,
      'syncStatus': syncMetadata.status.name,
      'lastSyncedAt': syncMetadata.lastSyncedAt?.toStorageIso(),
      'lastSyncError': syncMetadata.lastSyncError,
    };
  }

  void validate() {
    if (isMealLog && !isValidMealLog) {
      throw ArgumentError('Invalid meal log: Must have mealId and grams > 0');
    }
    if (isDirectMacroLog && !isValidDirectMacroLog) {
      throw ArgumentError(
        'Invalid direct macro log: Must have at least one macro > 0',
      );
    }
    if (!hasValidCalories) {
      AppLogger.warning(
        'Calorie mismatch for log "$mealName": '
        'stated $calories cal, calculated ${calculatedCalories.toStringAsFixed(1)} cal',
        category: 'nutrition',
      );
    }
  }

  static SyncStatus _syncStatusFromStorage(String? value) {
    return SyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncStatus.localOnly,
    );
  }
}
