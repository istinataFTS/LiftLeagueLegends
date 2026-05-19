import '../../core/enums/sync_entity_type.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/workout_set.dart';
import '../datasources/local/workout_set_local_datasource.dart';
import '../datasources/remote/workout_set_remote_datasource.dart';
import 'base_entity_sync_coordinator.dart';
import 'entity_sync_descriptor.dart';
import 'workout_set_sync_coordinator.dart';

class WorkoutSetSyncCoordinatorImpl
    extends BaseEntitySyncCoordinator<WorkoutSet>
    implements WorkoutSetSyncCoordinator {
  static const EntitySyncDescriptor _descriptor = EntitySyncDescriptor(
    entityType: SyncEntityType.workoutSet,
    operationKey: 'workout_set',
    entityLabel: 'workout set',
  );

  final WorkoutSetLocalDataSource localDataSource;
  final WorkoutSetRemoteDataSource remoteDataSource;

  const WorkoutSetSyncCoordinatorImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required super.pendingSyncDeleteLocalDataSource,
  });

  @override
  bool get isRemoteSyncEnabled => remoteDataSource.isConfigured;

  @override
  Future<void> prepareForInitialCloudMigration(String userId) {
    return localDataSource.prepareForInitialCloudMigration(userId: userId);
  }

  @override
  EntitySyncDescriptor get descriptor => _descriptor;

  @override
  String getEntityId(WorkoutSet entity) => entity.id;

  @override
  EntitySyncMetadata getSyncMetadata(WorkoutSet entity) => entity.syncMetadata;

  @override
  WorkoutSet buildAddedLocalEntity(WorkoutSet entity, DateTime now) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: guestAwareAddedSyncMetadata(
        entity.syncMetadata,
        entity.ownerUserId,
      ),
    );
  }

  @override
  WorkoutSet buildUpdatedLocalEntity({
    required WorkoutSet entity,
    required WorkoutSet? existingLocal,
    required DateTime now,
  }) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: guestAwareUpdatedSyncMetadata(
        incomingMetadata: entity.syncMetadata,
        existingLocalMetadata: existingLocal?.syncMetadata,
        ownerUserId: entity.ownerUserId,
      ),
    );
  }

  @override
  Future<void> insertLocal(WorkoutSet entity) {
    return localDataSource.addSet(entity);
  }

  @override
  Future<void> updateLocal(WorkoutSet entity) {
    return localDataSource.updateSet(entity);
  }

  @override
  Future<WorkoutSet?> getLocalById(String id) {
    return localDataSource.getSetById(id);
  }

  @override
  Future<void> deleteLocal(String id) {
    return localDataSource.deleteSet(id);
  }

  @override
  Future<List<WorkoutSet>> getPendingSyncEntities() {
    return localDataSource.getPendingSyncSets();
  }

  @override
  Future<WorkoutSet> upsertRemote(WorkoutSet entity) {
    return remoteDataSource.upsertSet(entity);
  }

  @override
  Future<void> deleteRemote({
    required String localId,
    required String? serverId,
  }) {
    return remoteDataSource.deleteSet(localId: localId, serverId: serverId);
  }

  @override
  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  }) {
    return localDataSource.markAsSynced(
      localId: localId,
      serverId: serverId,
      syncedAt: syncedAt,
    );
  }

  @override
  Future<void> markAsPendingUpload(
    String localId, {
    required String errorMessage,
  }) {
    return localDataSource.markAsPendingUpload(
      localId,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> markAsPendingUpdate(
    String localId, {
    required String errorMessage,
  }) {
    return localDataSource.markAsPendingUpdate(
      localId,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> markAsPendingDelete(String localId) {
    return localDataSource.markAsPendingDelete(localId);
  }

  @override
  Future<List<WorkoutSet>> fetchSince({
    required String userId,
    DateTime? since,
  }) {
    return remoteDataSource.fetchSince(userId: userId, since: since);
  }

  @override
  Future<void> persistAddedSet(WorkoutSet set) {
    return persistAdded(set);
  }

  @override
  Future<void> persistUpdatedSet(WorkoutSet set) {
    return persistUpdated(set);
  }

  @override
  Future<void> persistDeletedSet(String id) {
    return persistDeleted(id);
  }
}
