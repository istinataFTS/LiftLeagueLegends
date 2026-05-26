import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/enums/sync_status.dart';
import '../../../domain/entities/entity_sync_metadata.dart';
import '../../../domain/entities/workout_set.dart';

class SupabaseWorkoutSetDto {
  final String id;
  final String userId;
  final String exerciseId;
  final int reps;
  final double weight;
  final int intensity;
  final DateTime performedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupabaseWorkoutSetDto({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.reps,
    required this.weight,
    required this.intensity,
    required this.performedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupabaseWorkoutSetDto.fromMap(Map<String, dynamic> map) {
    return SupabaseWorkoutSetDto(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      exerciseId: map['exercise_id'] as String,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
      intensity: (map['intensity'] as int?) ?? MuscleStimulus.defaultIntensity,
      performedAt: DateTime.parse(map['performed_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory SupabaseWorkoutSetDto.fromEntity(WorkoutSet entity) {
    final ownerUserId = entity.ownerUserId;
    if (ownerUserId == null || ownerUserId.isEmpty) {
      throw ArgumentError(
        'WorkoutSet must have ownerUserId before conversion to Supabase DTO.',
      );
    }

    return SupabaseWorkoutSetDto(
      id: entity.syncMetadata.serverId ?? entity.id,
      userId: ownerUserId,
      exerciseId: entity.exerciseId,
      reps: entity.reps,
      weight: entity.weight,
      intensity: entity.intensity,
      performedAt: entity.date,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  WorkoutSet toEntity({
    required String localId,
    required EntitySyncMetadata syncMetadata,
  }) {
    return WorkoutSet(
      id: localId,
      ownerUserId: userId,
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      intensity: intensity,
      date: performedAt,
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
      'exercise_id': exerciseId,
      'reps': reps,
      'weight': weight,
      'intensity': intensity,
      'performed_at': performedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
