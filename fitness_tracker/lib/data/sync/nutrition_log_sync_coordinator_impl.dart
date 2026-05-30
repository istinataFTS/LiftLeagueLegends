import '../../core/enums/sync_entity_type.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/nutrition_log.dart';
import '../datasources/local/nutrition_log_local_datasource.dart';
import '../datasources/remote/nutrition_log_remote_datasource.dart';
import '../models/nutrition_log_model.dart';
import 'base_entity_sync_coordinator.dart';
import 'entity_sync_descriptor.dart';
import 'nutrition_log_sync_coordinator.dart';

class NutritionLogSyncCoordinatorImpl
    extends BaseEntitySyncCoordinator<NutritionLog>
    implements NutritionLogSyncCoordinator {
  static const EntitySyncDescriptor _descriptor = EntitySyncDescriptor(
    entityType: SyncEntityType.nutritionLog,
    operationKey: 'nutrition_log',
    entityLabel: 'nutrition log',
  );

  final NutritionLogLocalDataSource localDataSource;
  final NutritionLogRemoteDataSource remoteDataSource;

  const NutritionLogSyncCoordinatorImpl({
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
  String getEntityId(NutritionLog entity) => entity.id;

  @override
  EntitySyncMetadata getSyncMetadata(NutritionLog entity) =>
      entity.syncMetadata;

  @override
  NutritionLog buildAddedLocalEntity(NutritionLog entity, DateTime now) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: buildAddedSyncMetadata(entity.syncMetadata),
    );
  }

  @override
  NutritionLog buildUpdatedLocalEntity({
    required NutritionLog entity,
    required NutritionLog? existingLocal,
    required DateTime now,
  }) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: buildUpdatedSyncMetadata(
        incomingMetadata: entity.syncMetadata,
        existingLocalMetadata: existingLocal?.syncMetadata,
      ),
    );
  }

  @override
  Future<void> insertLocal(NutritionLog entity) {
    final model = NutritionLogModel.fromEntity(entity);
    model.validate();
    return localDataSource.insertLog(model);
  }

  @override
  Future<void> updateLocal(NutritionLog entity) {
    final model = NutritionLogModel.fromEntity(entity);
    model.validate();
    return localDataSource.updateLog(model);
  }

  @override
  Future<NutritionLog?> getLocalById(String id) {
    return localDataSource.getLogById(id);
  }

  @override
  Future<void> deleteLocal(String id) {
    return localDataSource.deleteLog(id);
  }

  @override
  Future<List<NutritionLog>> getPendingSyncEntities() {
    return localDataSource.getPendingSyncLogs();
  }

  @override
  Future<NutritionLog> upsertRemote(NutritionLog entity) {
    return remoteDataSource.upsertLog(entity);
  }

  @override
  Future<void> deleteRemote({
    required String localId,
    required String? serverId,
  }) {
    return remoteDataSource.deleteLog(localId: localId, serverId: serverId);
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
  Future<List<NutritionLog>> fetchSince({
    required String userId,
    DateTime? since,
  }) {
    return remoteDataSource.fetchSince(userId: userId, since: since);
  }

  @override
  Future<void> persistAddedLog(NutritionLog log) {
    return persistAdded(log);
  }

  @override
  Future<void> persistUpdatedLog(NutritionLog log) {
    return persistUpdated(log);
  }

  @override
  Future<void> persistDeletedLog(String id) {
    return persistDeleted(id);
  }
}
