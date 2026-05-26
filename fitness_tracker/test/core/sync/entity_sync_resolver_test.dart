import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/sync/entity_sync_resolver.dart';
import 'package:fitness_tracker/core/sync/sync_conflict_resolution.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

class TestEntity {
  final String id;
  final DateTime updatedAt;
  final EntitySyncMetadata syncMetadata;

  const TestEntity({
    required this.id,
    required this.updatedAt,
    this.syncMetadata = const EntitySyncMetadata(),
  });
}

void main() {
  final DateTime baseTime = DateTime(2026, 3, 26, 10, 0);

  final EntitySyncResolver<TestEntity> resolver =
      EntitySyncResolver<TestEntity>(
        getId: (entity) => entity.id,
        getUpdatedAt: (entity) => entity.updatedAt,
        getSyncMetadata: (entity) => entity.syncMetadata,
      );

  TestEntity buildEntity({
    required String id,
    required DateTime updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return TestEntity(id: id, updatedAt: updatedAt, syncMetadata: syncMetadata);
  }

  group('EntitySyncResolver.resolveConflict', () {
    test('keeps pending delete local entity over remote', () {
      final TestEntity local = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingDelete,
        ),
      );
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final SyncConflictResolution<TestEntity> resolution = resolver
          .resolveConflict(local: local, remote: remote);

      expect(resolution.winner, same(local));
      expect(resolution.outcome, SyncConflictOutcome.localPendingDelete);
      expect(resolution.keepsLocalChange, isTrue);
      expect(resolution.appliesRemoteChange, isFalse);
    });

    test('keeps pending update local entity over newer remote', () {
      final TestEntity local = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final SyncConflictResolution<TestEntity> resolution = resolver
          .resolveConflict(local: local, remote: remote);

      expect(resolution.winner, same(local));
      expect(resolution.outcome, SyncConflictOutcome.localPendingUpdate);
    });

    test('prefers remote when remote is newer and local is synced', () {
      final TestEntity local = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final SyncConflictResolution<TestEntity> resolution = resolver
          .resolveConflict(local: local, remote: remote);

      expect(resolution.winner, same(remote));
      expect(resolution.outcome, SyncConflictOutcome.remoteNewer);
      expect(resolution.appliesRemoteChange, isTrue);
    });

    test('prefers local when local is newer and synced', () {
      final TestEntity local = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
      );

      final SyncConflictResolution<TestEntity> resolution = resolver
          .resolveConflict(local: local, remote: remote);

      expect(resolution.winner, same(local));
      expect(resolution.outcome, SyncConflictOutcome.localNewer);
    });

    test('prefers local on equal timestamps for deterministic merges', () {
      final TestEntity local = buildEntity(id: 'entity-1', updatedAt: baseTime);
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
      );

      final SyncConflictResolution<TestEntity> resolution = resolver
          .resolveConflict(local: local, remote: remote);

      expect(resolution.winner, same(local));
      expect(resolution.outcome, SyncConflictOutcome.sameTimestampPreferLocal);
    });
  });

  group('EntitySyncResolver.mergeLists', () {
    test('omits local-only pending delete rows from merged lists', () {
      final List<TestEntity> merged = resolver.mergeLists(
        localItems: <TestEntity>[
          buildEntity(
            id: 'entity-1',
            updatedAt: baseTime,
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.pendingDelete,
            ),
          ),
        ],
        remoteItems: const <TestEntity>[],
      );

      expect(merged, isEmpty);
    });

    test('retains pending delete winner when remote still has the entity', () {
      final TestEntity localPendingDelete = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingDelete,
        ),
      );
      final TestEntity remote = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final List<TestEntity> merged = resolver.mergeLists(
        localItems: <TestEntity>[localPendingDelete],
        remoteItems: <TestEntity>[remote],
      );

      expect(merged, hasLength(1));
      expect(merged.single, same(localPendingDelete));
    });

    test('merges remote-only rows and preserves local pending changes', () {
      final TestEntity localPendingUpload = buildEntity(
        id: 'entity-1',
        updatedAt: baseTime,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpload,
        ),
      );
      final TestEntity remoteOnly = buildEntity(
        id: 'entity-2',
        updatedAt: baseTime.add(const Duration(hours: 1)),
      );

      final List<TestEntity> merged = resolver.mergeLists(
        localItems: <TestEntity>[localPendingUpload],
        remoteItems: <TestEntity>[remoteOnly],
      );

      expect(merged.map((entity) => entity.id).toSet(), <String>{
        'entity-1',
        'entity-2',
      });
      expect(
        merged.firstWhere((entity) => entity.id == 'entity-1'),
        same(localPendingUpload),
      );
    });
  });
}
