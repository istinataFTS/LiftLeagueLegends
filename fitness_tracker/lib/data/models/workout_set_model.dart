import '../../core/constants/database_tables.dart';
import '../../core/constants/muscle_stimulus_constants.dart';
import '../../core/enums/sync_status.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/workout_set.dart';

class WorkoutSetModel extends WorkoutSet {
  const WorkoutSetModel({
    required super.id,
    super.ownerUserId,
    required super.exerciseId,
    required super.reps,
    required super.weight,
    super.intensity = MuscleStimulus.defaultIntensity,
    required super.date,
    required super.createdAt,
    super.updatedAt,
    super.syncMetadata,
  });

  factory WorkoutSetModel.fromEntity(WorkoutSet set) {
    return WorkoutSetModel(
      id: set.id,
      ownerUserId: set.ownerUserId,
      exerciseId: set.exerciseId,
      reps: set.reps,
      weight: set.weight,
      intensity: set.intensity,
      date: set.date,
      createdAt: set.createdAt,
      updatedAt: set.updatedAt,
      syncMetadata: set.syncMetadata,
    );
  }

  factory WorkoutSetModel.fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.parse(
      map[DatabaseTables.setCreatedAt] as String,
    );
    final updatedAtRaw = map[DatabaseTables.setUpdatedAt] as String?;

    return WorkoutSetModel(
      id: map[DatabaseTables.setId] as String,
      ownerUserId: map['owner_user_id'] as String?,
      exerciseId: map[DatabaseTables.setExerciseId] as String,
      reps: map[DatabaseTables.setReps] as int,
      weight: (map[DatabaseTables.setWeight] as num).toDouble(),
      intensity:
          (map[DatabaseTables.setIntensity] as int?) ??
          MuscleStimulus.defaultIntensity,
      date: DateTime.parse(map[DatabaseTables.setDate] as String),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null
          ? createdAt
          : DateTime.parse(updatedAtRaw),
      syncMetadata: EntitySyncMetadata(
        serverId: map[DatabaseTables.setServerId] as String?,
        status: _syncStatusFromStorage(
          map[DatabaseTables.setSyncStatus] as String?,
        ),
        lastSyncedAt: _parseNullableDateTime(
          map[DatabaseTables.setLastSyncedAt] as String?,
        ),
        lastSyncError: map[DatabaseTables.setLastSyncError] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.setId: id,
      'owner_user_id': ownerUserId,
      DatabaseTables.setExerciseId: exerciseId,
      DatabaseTables.setReps: reps,
      DatabaseTables.setWeight: weight,
      DatabaseTables.setIntensity: intensity,
      DatabaseTables.setDate: date.toIso8601String(),
      DatabaseTables.setCreatedAt: createdAt.toIso8601String(),
      DatabaseTables.setUpdatedAt: updatedAt.toIso8601String(),
      DatabaseTables.setServerId: syncMetadata.serverId,
      DatabaseTables.setSyncStatus: syncMetadata.status.name,
      DatabaseTables.setLastSyncedAt: syncMetadata.lastSyncedAt
          ?.toIso8601String(),
      DatabaseTables.setLastSyncError: syncMetadata.lastSyncError,
    };
  }

  factory WorkoutSetModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final updatedAtRaw = json['updatedAt'] as String?;

    return WorkoutSetModel(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String?,
      exerciseId: json['exerciseId'] as String,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      intensity: (json['intensity'] as int?) ?? MuscleStimulus.defaultIntensity,
      date: DateTime.parse(json['date'] as String),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null
          ? createdAt
          : DateTime.parse(updatedAtRaw),
      syncMetadata: EntitySyncMetadata(
        serverId: json['serverId'] as String?,
        status: _syncStatusFromStorage(json['syncStatus'] as String?),
        lastSyncedAt: _parseNullableDateTime(json['lastSyncedAt'] as String?),
        lastSyncError: json['lastSyncError'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'exerciseId': exerciseId,
      'reps': reps,
      'weight': weight,
      'intensity': intensity,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'serverId': syncMetadata.serverId,
      'syncStatus': syncMetadata.status.name,
      'lastSyncedAt': syncMetadata.lastSyncedAt?.toIso8601String(),
      'lastSyncError': syncMetadata.lastSyncError,
    };
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
