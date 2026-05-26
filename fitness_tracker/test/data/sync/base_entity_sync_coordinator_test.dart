import 'package:fitness_tracker/core/enums/sync_entity_type.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/datasources/local/pending_sync_delete_local_datasource.dart';
import 'package:fitness_tracker/data/sync/base_entity_sync_coordinator.dart';
import 'package:fitness_tracker/data/sync/entity_sync_batch_failure.dart';
import 'package:fitness_tracker/data/sync/entity_sync_descriptor.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/pending_sync_delete.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSyncEntity {
  final String id;
  final EntitySyncMetadata syncMetadata;

  const TestSyncEntity({required this.id, required this.syncMetadata});

  TestSyncEntity copyWith({String? id, EntitySyncMetadata? syncMetadata}) {
    return TestSyncEntity(
      id: id ?? this.id,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }
}

class InMemoryPendingSyncDeleteLocalDataSource
    implements PendingSyncDeleteLocalDataSource {
  final List<PendingSyncDelete> operations = <PendingSyncDelete>[];
  final List<String> removedIds = <String>[];
  final List<String> attemptedIds = <String>[];

  @override
  Future<void> enqueue(PendingSyncDelete operation) async {
    operations.add(operation);
  }

  @override
  Future<List<PendingSyncDelete>> getPendingByEntityType(
    SyncEntityType entityType,
  ) async {
    return operations
        .where((operation) => operation.entityType == entityType)
        .toList();
  }

  @override
  Future<void> markAttempted(
    String operationId, {
    required DateTime attemptedAt,
    String? errorMessage,
  }) async {
    attemptedIds.add(operationId);
  }

  @override
  Future<void> remove(String operationId) async {
    removedIds.add(operationId);
    operations.removeWhere((operation) => operation.id == operationId);
  }

  @override
  Future<void> clearAll() async {
    operations.clear();
    removedIds.clear();
    attemptedIds.clear();
  }
}

class TestEntitySyncCoordinator
    extends BaseEntitySyncCoordinator<TestSyncEntity> {
  static const EntitySyncDescriptor _descriptor = EntitySyncDescriptor(
    entityType: SyncEntityType.target,
    operationKey: 'test_entity',
    entityLabel: 'test entity',
  );

  final Map<String, TestSyncEntity> localStore = <String, TestSyncEntity>{};
  final Set<String> remoteUpsertFailures;
  final Set<String> remoteDeleteFailures;
  final List<String> remoteUpsertCalls = <String>[];
  final List<String> remoteDeleteCalls = <String>[];
  final List<String> syncedIds = <String>[];
  final List<String> pendingUploadIds = <String>[];
  final List<String> pendingUpdateIds = <String>[];
  final List<String> pendingDeleteIds = <String>[];

  TestEntitySyncCoordinator({
    required super.pendingSyncDeleteLocalDataSource,
    this.remoteUpsertFailures = const <String>{},
    this.remoteDeleteFailures = const <String>{},
  });

  @override
  bool get isRemoteSyncEnabled => true;

  @override
  EntitySyncDescriptor get descriptor => _descriptor;

  @override
  String getEntityId(TestSyncEntity entity) => entity.id;

  @override
  EntitySyncMetadata getSyncMetadata(TestSyncEntity entity) =>
      entity.syncMetadata;

  @override
  TestSyncEntity buildAddedLocalEntity(TestSyncEntity entity, DateTime now) {
    return entity.copyWith(
      syncMetadata: entity.syncMetadata.copyWith(
        status: SyncStatus.pendingUpload,
        clearLastSyncError: true,
      ),
    );
  }

  @override
  TestSyncEntity buildUpdatedLocalEntity({
    required TestSyncEntity entity,
    required TestSyncEntity? existingLocal,
    required DateTime now,
  }) {
    return entity;
  }

  @override
  Future<void> insertLocal(TestSyncEntity entity) async {
    localStore[entity.id] = entity;
  }

  @override
  Future<void> updateLocal(TestSyncEntity entity) async {
    localStore[entity.id] = entity;
  }

  @override
  Future<TestSyncEntity?> getLocalById(String id) async {
    return localStore[id];
  }

  @override
  Future<void> deleteLocal(String id) async {
    localStore.remove(id);
  }

  @override
  Future<List<TestSyncEntity>> getPendingSyncEntities() async {
    return localStore.values.toList();
  }

  @override
  Future<TestSyncEntity> upsertRemote(TestSyncEntity entity) async {
    remoteUpsertCalls.add(entity.id);

    if (remoteUpsertFailures.contains(entity.id)) {
      throw StateError('remote upsert failed for ${entity.id}');
    }

    return entity.copyWith(
      syncMetadata: entity.syncMetadata.copyWith(
        serverId: 'server-${entity.id}',
        status: SyncStatus.synced,
        clearLastSyncError: true,
      ),
    );
  }

  @override
  Future<List<TestSyncEntity>> fetchSince({
    required String userId,
    DateTime? since,
  }) async {
    // Not exercised in base-coordinator unit tests; pull-path is tested
    // separately via pullRemoteChanges integration tests.
    return const <TestSyncEntity>[];
  }

  @override
  Future<void> deleteRemote({
    required String localId,
    required String? serverId,
  }) async {
    remoteDeleteCalls.add(localId);

    if (remoteDeleteFailures.contains(localId)) {
      throw StateError('remote delete failed for $localId');
    }
  }

  @override
  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  }) async {
    syncedIds.add(localId);

    final existing = localStore[localId]!;
    localStore[localId] = existing.copyWith(
      syncMetadata: existing.syncMetadata.copyWith(
        serverId: serverId,
        status: SyncStatus.synced,
        lastSyncedAt: syncedAt,
        clearLastSyncError: true,
      ),
    );
  }

  @override
  Future<void> markAsPendingUpload(
    String localId, {
    required String errorMessage,
  }) async {
    pendingUploadIds.add(localId);

    final existing = localStore[localId]!;
    localStore[localId] = existing.copyWith(
      syncMetadata: existing.syncMetadata.copyWith(
        status: SyncStatus.pendingUpload,
        lastSyncError: errorMessage,
      ),
    );
  }

  @override
  Future<void> markAsPendingUpdate(
    String localId, {
    required String errorMessage,
  }) async {
    pendingUpdateIds.add(localId);

    final existing = localStore[localId]!;
    localStore[localId] = existing.copyWith(
      syncMetadata: existing.syncMetadata.copyWith(
        status: SyncStatus.pendingUpdate,
        lastSyncError: errorMessage,
      ),
    );
  }

  @override
  Future<void> markAsPendingDelete(String localId) async {
    pendingDeleteIds.add(localId);

    final existing = localStore[localId]!;
    localStore[localId] = existing.copyWith(
      syncMetadata: existing.syncMetadata.copyWith(
        status: SyncStatus.pendingDelete,
      ),
    );
  }
}

void main() {
  late InMemoryPendingSyncDeleteLocalDataSource pendingDeleteDataSource;
  late TestEntitySyncCoordinator coordinator;

  setUp(() {
    pendingDeleteDataSource = InMemoryPendingSyncDeleteLocalDataSource();
    coordinator = TestEntitySyncCoordinator(
      pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
    );
  });

  test(
    'syncPendingChanges continues after entity upsert failure, flushes deletes, and throws structured failure at end',
    () async {
      coordinator = TestEntitySyncCoordinator(
        pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
        remoteUpsertFailures: const <String>{'entity-1'},
      );

      coordinator.localStore['entity-1'] = const TestSyncEntity(
        id: 'entity-1',
        syncMetadata: EntitySyncMetadata(status: SyncStatus.pendingUpload),
      );
      coordinator.localStore['entity-2'] = const TestSyncEntity(
        id: 'entity-2',
        syncMetadata: EntitySyncMetadata(status: SyncStatus.pendingUpdate),
      );
      coordinator.localStore['entity-3'] = const TestSyncEntity(
        id: 'entity-3',
        syncMetadata: EntitySyncMetadata(
          status: SyncStatus.pendingDelete,
          serverId: 'server-entity-3',
        ),
      );

      await pendingDeleteDataSource.enqueue(
        PendingSyncDelete(
          id: 'delete-1',
          entityType: SyncEntityType.target,
          localEntityId: 'entity-3',
          serverEntityId: 'server-entity-3',
          createdAt: DateTime(2026, 3, 25),
        ),
      );

      await expectLater(
        coordinator.syncPendingChanges(),
        throwsA(
          isA<EntitySyncBatchFailure>()
              .having(
                (error) => error.failedUpsertEntityIds,
                'failedUpsertEntityIds',
                <String>['entity-1'],
              )
              .having(
                (error) => error.failedDeleteEntityIds,
                'failedDeleteEntityIds',
                isEmpty,
              )
              .having(
                (error) => error.message,
                'message',
                contains('failed to upsert 1 test entity entry (entity-1)'),
              ),
        ),
      );

      expect(coordinator.remoteUpsertCalls, <String>['entity-1', 'entity-2']);
      expect(coordinator.syncedIds, <String>['entity-2']);
      expect(coordinator.pendingUploadIds, <String>['entity-1']);
      expect(coordinator.remoteDeleteCalls, <String>['entity-3']);
      expect(pendingDeleteDataSource.removedIds, <String>['delete-1']);
      expect(coordinator.localStore.containsKey('entity-3'), isFalse);
    },
  );

  test(
    'syncPendingChanges preserves pending update status on retry failure',
    () async {
      coordinator = TestEntitySyncCoordinator(
        pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
        remoteUpsertFailures: const <String>{'entity-1'},
      );

      coordinator.localStore['entity-1'] = const TestSyncEntity(
        id: 'entity-1',
        syncMetadata: EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
          serverId: 'server-entity-1',
        ),
      );

      await expectLater(
        coordinator.syncPendingChanges(),
        throwsA(
          isA<EntitySyncBatchFailure>().having(
            (error) => error.failedUpsertEntityIds,
            'failedUpsertEntityIds',
            <String>['entity-1'],
          ),
        ),
      );

      expect(coordinator.pendingUpdateIds, <String>['entity-1']);
      expect(
        coordinator.localStore['entity-1']!.syncMetadata.status,
        SyncStatus.pendingUpdate,
      );
      expect(
        coordinator.localStore['entity-1']!.syncMetadata.lastSyncError,
        contains('remote upsert failed for entity-1'),
      );
    },
  );

  test('syncPendingChanges throws when pending deletes fail', () async {
    coordinator = TestEntitySyncCoordinator(
      pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
      remoteDeleteFailures: const <String>{'entity-3'},
    );

    coordinator.localStore['entity-3'] = const TestSyncEntity(
      id: 'entity-3',
      syncMetadata: EntitySyncMetadata(
        status: SyncStatus.pendingDelete,
        serverId: 'server-entity-3',
      ),
    );

    await pendingDeleteDataSource.enqueue(
      PendingSyncDelete(
        id: 'delete-1',
        entityType: SyncEntityType.target,
        localEntityId: 'entity-3',
        serverEntityId: 'server-entity-3',
        createdAt: DateTime(2026, 3, 25),
      ),
    );

    await expectLater(
      coordinator.syncPendingChanges(),
      throwsA(
        isA<EntitySyncBatchFailure>()
            .having(
              (error) => error.failedUpsertEntityIds,
              'failedUpsertEntityIds',
              isEmpty,
            )
            .having(
              (error) => error.failedDeleteEntityIds,
              'failedDeleteEntityIds',
              <String>['entity-3'],
            )
            .having(
              (error) => error.message,
              'message',
              contains('failed to delete 1 test entity entry (entity-3)'),
            ),
      ),
    );

    expect(coordinator.remoteDeleteCalls, <String>['entity-3']);
    expect(pendingDeleteDataSource.attemptedIds, <String>['delete-1']);
    expect(coordinator.localStore.containsKey('entity-3'), isTrue);
  });

  group('localOnly write-through guard', () {
    // Regression for the boot-time AuthSyncException log spam: rows whose
    // metadata is intentionally `localOnly` (e.g. guest-owned writes via
    // the guest-aware metadata builders) must NOT trigger an upsertRemote
    // call. Pushing them anyway just floods the logs with
    // "unauthenticated" failures that the user cannot act on.
    test('persistAdded skips remote push when metadata is localOnly', () async {
      final localOnlyCoordinator = _LocalOnlyAddedCoordinator(
        pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
      );

      await localOnlyCoordinator.persistAdded(
        const TestSyncEntity(
          id: 'guest-entity',
          syncMetadata: EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );

      expect(
        localOnlyCoordinator.remoteUpsertCalls,
        isEmpty,
        reason:
            'localOnly rows are in their terminal state — pushing them just '
            'spams the log with intentional failures',
      );
      expect(localOnlyCoordinator.syncedIds, isEmpty);
      expect(localOnlyCoordinator.pendingUploadIds, isEmpty);
      expect(
        localOnlyCoordinator.localStore['guest-entity']!.syncMetadata.status,
        SyncStatus.localOnly,
      );
    });

    test('persistAdded still pushes when metadata is pendingUpload', () async {
      // Sanity check that the guard only fires on localOnly — normal
      // write-through must keep its existing push behaviour.
      await coordinator.persistAdded(
        const TestSyncEntity(
          id: 'normal-entity',
          syncMetadata: EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );

      // Base TestCoordinator's buildAddedLocalEntity rewrites status to
      // pendingUpload, so the push should run.
      expect(coordinator.remoteUpsertCalls, <String>['normal-entity']);
      expect(coordinator.syncedIds, <String>['normal-entity']);
    });

    test(
      'persistUpdated skips remote push when metadata is localOnly',
      () async {
        final localOnlyCoordinator = _LocalOnlyUpdatedCoordinator(
          pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
        );

        localOnlyCoordinator.localStore['guest-entity'] = const TestSyncEntity(
          id: 'guest-entity',
          syncMetadata: EntitySyncMetadata(status: SyncStatus.localOnly),
        );

        await localOnlyCoordinator.persistUpdated(
          const TestSyncEntity(
            id: 'guest-entity',
            syncMetadata: EntitySyncMetadata(status: SyncStatus.localOnly),
          ),
        );

        expect(localOnlyCoordinator.remoteUpsertCalls, isEmpty);
        expect(localOnlyCoordinator.pendingUpdateIds, isEmpty);
        expect(localOnlyCoordinator.pendingUploadIds, isEmpty);
      },
    );
  });
}

/// TestCoordinator variant whose `buildAddedLocalEntity` preserves a
/// `localOnly` status (mirroring `guestAwareAddedSyncMetadata` for a
/// guest-owned write). Used to exercise the localOnly skip branch
/// without coupling the test to a specific entity type's helpers.
class _LocalOnlyAddedCoordinator extends TestEntitySyncCoordinator {
  _LocalOnlyAddedCoordinator({required super.pendingSyncDeleteLocalDataSource});

  @override
  TestSyncEntity buildAddedLocalEntity(TestSyncEntity entity, DateTime now) {
    return entity.copyWith(
      syncMetadata: entity.syncMetadata.copyWith(
        status: SyncStatus.localOnly,
        clearLastSyncError: true,
      ),
    );
  }
}

/// TestCoordinator variant whose `buildUpdatedLocalEntity` preserves a
/// `localOnly` status (mirroring `guestAwareUpdatedSyncMetadata`).
class _LocalOnlyUpdatedCoordinator extends TestEntitySyncCoordinator {
  _LocalOnlyUpdatedCoordinator({
    required super.pendingSyncDeleteLocalDataSource,
  });

  @override
  TestSyncEntity buildUpdatedLocalEntity({
    required TestSyncEntity entity,
    required TestSyncEntity? existingLocal,
    required DateTime now,
  }) {
    return entity.copyWith(
      syncMetadata: entity.syncMetadata.copyWith(
        status: SyncStatus.localOnly,
        clearLastSyncError: true,
      ),
    );
  }
}
