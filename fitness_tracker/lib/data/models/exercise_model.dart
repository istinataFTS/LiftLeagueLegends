import 'dart:convert';

import '../../core/constants/database_tables.dart';
import '../../core/enums/sync_status.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/exercise.dart';

class ExerciseModel extends Exercise {
  const ExerciseModel({
    required super.id,
    super.ownerUserId,
    required super.name,
    required super.muscleGroups,
    required super.createdAt,
    super.updatedAt,
    super.syncMetadata,
  });

  factory ExerciseModel.fromEntity(Exercise exercise) {
    return ExerciseModel(
      id: exercise.id,
      ownerUserId: exercise.ownerUserId,
      name: exercise.name,
      muscleGroups: exercise.muscleGroups,
      createdAt: exercise.createdAt,
      updatedAt: exercise.updatedAt,
      syncMetadata: exercise.syncMetadata,
    );
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.parse(
      map[DatabaseTables.exerciseCreatedAt] as String,
    );
    final updatedAtRaw = map[DatabaseTables.exerciseUpdatedAt] as String?;

    return ExerciseModel(
      id: map[DatabaseTables.exerciseId] as String,
      ownerUserId: map[DatabaseTables.ownerUserId] as String?,
      name: map[DatabaseTables.exerciseName] as String,
      muscleGroups: _normaliseMuscleGroups(
        _decodeMuscleGroups(map[DatabaseTables.exerciseMuscleGroups] as String),
      ),
      createdAt: createdAt,
      updatedAt: updatedAtRaw == null
          ? createdAt
          : DateTime.parse(updatedAtRaw),
      syncMetadata: EntitySyncMetadata(
        serverId: map[DatabaseTables.exerciseServerId] as String?,
        status: _syncStatusFromStorage(
          map[DatabaseTables.exerciseSyncStatus] as String?,
        ),
        lastSyncedAt: _parseNullableDateTime(
          map[DatabaseTables.exerciseLastSyncedAt] as String?,
        ),
        lastSyncError: map[DatabaseTables.exerciseLastSyncError] as String?,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.exerciseId: id,
      DatabaseTables.ownerUserId: ownerUserId,
      DatabaseTables.exerciseName: name,
      DatabaseTables.exerciseMuscleGroups: _encodeMuscleGroups(muscleGroups),
      DatabaseTables.exerciseCreatedAt: createdAt.toIso8601String(),
      DatabaseTables.exerciseUpdatedAt: updatedAt.toIso8601String(),
      DatabaseTables.exerciseServerId: syncMetadata.serverId,
      DatabaseTables.exerciseSyncStatus: syncMetadata.status.name,
      DatabaseTables.exerciseLastSyncedAt: syncMetadata.lastSyncedAt
          ?.toIso8601String(),
      DatabaseTables.exerciseLastSyncError: syncMetadata.lastSyncError,
    };
  }

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final updatedAtRaw = json['updatedAt'] as String?;

    return ExerciseModel(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String?,
      name: json['name'] as String,
      muscleGroups: _normaliseMuscleGroups(
        (json['muscleGroups'] as List).cast<String>(),
      ),
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
      'name': name,
      'muscleGroups': muscleGroups,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'serverId': syncMetadata.serverId,
      'syncStatus': syncMetadata.status.name,
      'lastSyncedAt': syncMetadata.lastSyncedAt?.toIso8601String(),
      'lastSyncError': syncMetadata.lastSyncError,
    };
  }

  static String _encodeMuscleGroups(List<String> muscleGroups) {
    return jsonEncode(_normaliseMuscleGroups(muscleGroups));
  }

  /// Canonicalises muscle-group identifiers to lowercase + trimmed form.
  ///
  /// Applied at every ingestion point (DB read, JSON read, write-back) so
  /// the rest of the codebase can assume groups are already in canonical
  /// form.  Prevents case-mismatch drops in mappers like
  /// `HomeViewDataMapper._buildMuscleBreakdown`.
  static List<String> _normaliseMuscleGroups(List<String> raw) {
    return raw.map((m) => m.trim().toLowerCase()).toList(growable: false);
  }

  static List<String> _decodeMuscleGroups(String json) {
    try {
      final decoded = jsonDecode(json) as List;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return const <String>[];
    }
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
