import '../../core/enums/sync_entity_type.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import '../../domain/entities/exercise.dart';
import '../datasources/local/exercise_local_datasource.dart';
import '../datasources/remote/exercise_remote_datasource.dart';
import '../models/exercise_model.dart';
import 'base_entity_sync_coordinator.dart';
import 'entity_sync_descriptor.dart';
import 'exercise_sync_coordinator.dart';

class ExerciseSyncCoordinatorImpl extends BaseEntitySyncCoordinator<Exercise>
    implements ExerciseSyncCoordinator {
  static const EntitySyncDescriptor _descriptor = EntitySyncDescriptor(
    entityType: SyncEntityType.exercise,
    operationKey: 'exercise',
    entityLabel: 'exercise',
  );

  final ExerciseLocalDataSource localDataSource;
  final ExerciseRemoteDataSource remoteDataSource;

  const ExerciseSyncCoordinatorImpl({
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
  String getEntityId(Exercise entity) => entity.id;

  @override
  EntitySyncMetadata getSyncMetadata(Exercise entity) => entity.syncMetadata;

  @override
  Exercise buildAddedLocalEntity(Exercise entity, DateTime now) {
    return entity.copyWith(
      updatedAt: now,
      syncMetadata: buildAddedSyncMetadata(entity.syncMetadata),
    );
  }

  @override
  Exercise buildUpdatedLocalEntity({
    required Exercise entity,
    required Exercise? existingLocal,
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

  /// Inserts a remote-pulled exercise locally, reconciling against the
  /// `UNIQUE(name, COALESCE(owner_user_id, ''))` constraint.
  ///
  /// The base coordinator already checked `getLocalById(remoteId)` and
  /// found nothing — but a different local row may still own the
  /// `(name, ownerUserId)` slot. That happens when the same logical
  /// exercise was created on another device (or seeded server-side) with
  /// a different `id` than the one we minted locally. A blind insert
  /// trips the UNIQUE index and aborts the entire feature pull.
  ///
  /// Reconciliation strategy: when a name+owner conflict is detected we
  /// adopt the remote payload **on top of the existing local id**. Keeping
  /// the local id preserves referential integrity for child rows
  /// (`workout_sets.exercise_id`, `exercise_muscle_factors.exercise_id`)
  /// that already point at it; the cloud's id is captured separately as
  /// `serverId` via the standard sync metadata.
  @override
  Future<void> insertLocal(Exercise entity) async {
    final existing = await localDataSource.getByNameAndOwner(
      name: entity.name,
      ownerUserId: entity.ownerUserId,
    );

    if (existing != null && existing.id != entity.id) {
      final reconciled = entity.copyWith(
        id: existing.id,
        syncMetadata: entity.syncMetadata.copyWith(
          serverId: entity.syncMetadata.serverId ?? entity.id,
        ),
      );
      await localDataSource.updateExercise(
        ExerciseModel.fromEntity(reconciled),
      );
      return;
    }

    await localDataSource.insertExercise(ExerciseModel.fromEntity(entity));
  }

  @override
  Future<void> updateLocal(Exercise entity) {
    return localDataSource.updateExercise(ExerciseModel.fromEntity(entity));
  }

  @override
  Future<Exercise?> getLocalById(String id) {
    return localDataSource.getExerciseById(id);
  }

  @override
  Future<void> deleteLocal(String id) {
    return localDataSource.deleteExercise(id);
  }

  @override
  Future<List<Exercise>> getPendingSyncEntities() {
    return localDataSource.getPendingSyncExercises();
  }

  @override
  Future<Exercise> upsertRemote(Exercise entity) {
    return remoteDataSource.upsertExercise(entity);
  }

  @override
  Future<void> deleteRemote({
    required String localId,
    required String? serverId,
  }) {
    return remoteDataSource.deleteExercise(
      localId: localId,
      serverId: serverId,
    );
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
  Future<List<Exercise>> fetchSince({required String userId, DateTime? since}) {
    return remoteDataSource.fetchSince(userId: userId, since: since);
  }

  /// Reconciles `(name, owner)` collisions during pull.
  ///
  /// The local schema enforces `UNIQUE(name, COALESCE(owner_user_id, ''))`.
  /// The cloud has no equivalent constraint, and historical data can contain
  /// multiple rows for the same logical exercise — for example because an
  /// earlier app version uploaded seeded system exercises with their seed
  /// ids alongside the user's own copy of the same name. A naive id-keyed
  /// pull would either fail the `UNIQUE` index directly (when no local row
  /// matches the remote id but a different local row already owns the
  /// `(name, owner)` slot) or fail later in the same pull when a second
  /// remote row tries to claim the same slot. Either failure aborts the
  /// initial cloud migration step and breaks sign-in.
  ///
  /// Resolution: keep whichever local row already owns the `(name, owner)`
  /// slot (children stay attached to its id), overwrite its content with
  /// the remote payload, and adopt the remote id as `serverId`. If a stale
  /// local alias exists under the remote id, drop it. Muscle factors are
  /// reattached by the post-sync heal hook.
  @override
  Future<bool> persistRemotePulledRow(Exercise remote) async {
    final byId = await localDataSource.getExerciseById(remote.id);
    final byNameOwner = await localDataSource.findStoredExerciseByNameAndOwner(
      name: remote.name,
      ownerUserId: remote.ownerUserId,
    );

    if (byNameOwner == null) {
      if (byId != null) {
        await localDataSource.updateExercise(ExerciseModel.fromEntity(remote));
        return false;
      }
      await localDataSource.insertExercise(ExerciseModel.fromEntity(remote));
      return true;
    }

    if (byId != null && byId.id == byNameOwner.id) {
      await localDataSource.updateExercise(ExerciseModel.fromEntity(remote));
      return false;
    }

    final mergedId = byNameOwner.id;
    final merged = remote.copyWith(id: mergedId);
    await localDataSource.updateExercise(ExerciseModel.fromEntity(merged));

    if (byId != null && byId.id != mergedId) {
      await localDataSource.deleteExercise(byId.id);
    }

    AppLogger.warning(
      'Reconciled (name, owner) collision during exercise pull: '
      'kept local id $mergedId for "${remote.name}" '
      '(remote id ${remote.id})',
      category: 'sync',
    );
    return false;
  }

  @override
  Future<void> persistAddedExercise(Exercise exercise) {
    return persistAdded(exercise);
  }

  @override
  Future<void> persistUpdatedExercise(Exercise exercise) {
    return persistUpdated(exercise);
  }

  @override
  Future<void> persistDeletedExercise(String id) {
    return persistDeleted(id);
  }
}
