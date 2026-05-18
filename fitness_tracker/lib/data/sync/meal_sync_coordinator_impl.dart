import '../../core/enums/sync_entity_type.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/meal.dart';
import '../datasources/local/meal_local_datasource.dart';
import '../datasources/remote/meal_remote_datasource.dart';
import '../models/meal_model.dart';
import 'base_entity_sync_coordinator.dart';
import 'entity_sync_descriptor.dart';
import 'meal_sync_coordinator.dart';

class MealSyncCoordinatorImpl extends BaseEntitySyncCoordinator<Meal>
    implements MealSyncCoordinator {
  static const EntitySyncDescriptor _descriptor = EntitySyncDescriptor(
    entityType: SyncEntityType.meal,
    operationKey: 'meal',
    entityLabel: 'meal',
  );

  final MealLocalDataSource localDataSource;
  final MealRemoteDataSource remoteDataSource;

  const MealSyncCoordinatorImpl({
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
  String getEntityId(Meal entity) => entity.id;

  @override
  EntitySyncMetadata getSyncMetadata(Meal entity) => entity.syncMetadata;

  @override
  Meal buildAddedLocalEntity(Meal entity, DateTime now) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: guestAwareAddedSyncMetadata(
        entity.syncMetadata,
        entity.ownerUserId,
      ),
    );
  }

  @override
  Meal buildUpdatedLocalEntity({
    required Meal entity,
    required Meal? existingLocal,
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
  Future<void> insertLocal(Meal entity) {
    final model = MealModel.fromEntity(entity);
    model.validateMacros();
    model.validateAndLogCalories();
    return localDataSource.insertMeal(model);
  }

  @override
  Future<void> updateLocal(Meal entity) {
    final model = MealModel.fromEntity(entity);
    model.validateMacros();
    model.validateAndLogCalories();
    return localDataSource.updateMeal(model);
  }

  @override
  Future<Meal?> getLocalById(String id) {
    return localDataSource.getMealById(id);
  }

  @override
  Future<void> deleteLocal(String id) {
    return localDataSource.deleteMeal(id);
  }

  @override
  Future<List<Meal>> getPendingSyncEntities() {
    return localDataSource.getPendingSyncMeals();
  }

  @override
  Future<Meal> upsertRemote(Meal entity) {
    return remoteDataSource.upsertMeal(entity);
  }

  @override
  Future<void> deleteRemote({
    required String localId,
    required String? serverId,
  }) {
    return remoteDataSource.deleteMeal(localId: localId, serverId: serverId);
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
  Future<List<Meal>> fetchSince({required String userId, DateTime? since}) {
    return remoteDataSource.fetchSince(userId: userId, since: since);
  }

  /// See [ExerciseSyncCoordinatorImpl.persistRemotePulledRow] for the full
  /// rationale. The local schema enforces
  /// `UNIQUE(name, COALESCE(owner_user_id, ''))` on meals as well, and the
  /// cloud has no equivalent constraint, so the same `(name, owner)`
  /// collision can break the meals migration step.
  @override
  Future<bool> persistRemotePulledRow(Meal remote) async {
    final byId = await localDataSource.getMealById(remote.id);
    final byNameOwner = await localDataSource.findStoredMealByNameAndOwner(
      name: remote.name,
      ownerUserId: remote.ownerUserId,
    );

    final model = MealModel.fromEntity(remote);
    model.validateMacros();
    model.validateAndLogCalories();

    if (byNameOwner == null) {
      if (byId != null) {
        await localDataSource.updateMeal(model);
        return false;
      }
      await localDataSource.insertMeal(model);
      return true;
    }

    if (byId != null && byId.id == byNameOwner.id) {
      await localDataSource.updateMeal(model);
      return false;
    }

    final mergedId = byNameOwner.id;
    final mergedModel = MealModel.fromEntity(remote.copyWith(id: mergedId));
    mergedModel.validateMacros();
    mergedModel.validateAndLogCalories();
    await localDataSource.updateMeal(mergedModel);

    if (byId != null && byId.id != mergedId) {
      await localDataSource.deleteMeal(byId.id);
    }

    AppLogger.warning(
      'Reconciled (name, owner) collision during meal pull: '
      'kept local id $mergedId for "${remote.name}" '
      '(remote id ${remote.id})',
      category: 'sync',
    );
    return false;
  }

  @override
  Future<void> persistAddedMeal(Meal meal) {
    return persistAdded(meal);
  }

  @override
  Future<void> persistUpdatedMeal(Meal meal) {
    return persistUpdated(meal);
  }

  @override
  Future<void> persistDeletedMeal(String id) {
    return persistDeleted(id);
  }
}
