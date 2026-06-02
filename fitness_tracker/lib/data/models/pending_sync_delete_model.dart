import '../../core/constants/database_tables.dart';
import '../../core/enums/sync_entity_type.dart';
import '../../core/utils/date_serialization.dart';
import '../../domain/entities/pending_sync_delete.dart';

class PendingSyncDeleteModel extends PendingSyncDelete {
  const PendingSyncDeleteModel({
    required super.id,
    required super.entityType,
    required super.localEntityId,
    super.serverEntityId,
    required super.createdAt,
    super.lastAttemptAt,
    super.errorMessage,
  });

  factory PendingSyncDeleteModel.fromEntity(PendingSyncDelete entity) {
    return PendingSyncDeleteModel(
      id: entity.id,
      entityType: entity.entityType,
      localEntityId: entity.localEntityId,
      serverEntityId: entity.serverEntityId,
      createdAt: entity.createdAt,
      lastAttemptAt: entity.lastAttemptAt,
      errorMessage: entity.errorMessage,
    );
  }

  factory PendingSyncDeleteModel.fromMap(Map<String, dynamic> map) {
    return PendingSyncDeleteModel(
      id: map[DatabaseTables.pendingDeleteId] as String,
      entityType: SyncEntityType.values.firstWhere(
        (type) => type.name == map[DatabaseTables.pendingDeleteEntityType],
        orElse: () => SyncEntityType.workoutSet,
      ),
      localEntityId: map[DatabaseTables.pendingDeleteLocalEntityId] as String,
      serverEntityId:
          map[DatabaseTables.pendingDeleteServerEntityId] as String?,
      createdAt: parseStorageDate(
        map[DatabaseTables.pendingDeleteCreatedAt] as String,
      ),
      lastAttemptAt: parseStorageDateOrNull(
        map[DatabaseTables.pendingDeleteLastAttemptAt] as String?,
      ),
      errorMessage: map[DatabaseTables.pendingDeleteErrorMessage] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.pendingDeleteId: id,
      DatabaseTables.pendingDeleteEntityType: entityType.name,
      DatabaseTables.pendingDeleteLocalEntityId: localEntityId,
      DatabaseTables.pendingDeleteServerEntityId: serverEntityId,
      DatabaseTables.pendingDeleteCreatedAt: createdAt.toStorageIso(),
      DatabaseTables.pendingDeleteLastAttemptAt: lastAttemptAt?.toStorageIso(),
      DatabaseTables.pendingDeleteErrorMessage: errorMessage,
    };
  }
}
