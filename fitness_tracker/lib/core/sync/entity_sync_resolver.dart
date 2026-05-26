import '../enums/sync_status.dart';
import '../../domain/entities/entity_sync_metadata.dart';
import 'sync_conflict_resolution.dart';

typedef EntityIdGetter<T> = String Function(T entity);
typedef EntityUpdatedAtGetter<T> = DateTime Function(T entity);
typedef EntitySyncMetadataGetter<T> = EntitySyncMetadata Function(T entity);

class EntitySyncResolver<T> {
  final EntityIdGetter<T> getId;
  final EntityUpdatedAtGetter<T> getUpdatedAt;
  final EntitySyncMetadataGetter<T> getSyncMetadata;

  const EntitySyncResolver({
    required this.getId,
    required this.getUpdatedAt,
    required this.getSyncMetadata,
  });

  List<T> mergeLists({
    required List<T> localItems,
    required List<T> remoteItems,
  }) {
    final Map<String, T> localById = <String, T>{
      for (final item in localItems) getId(item): item,
    };

    final Map<String, T> remoteById = <String, T>{
      for (final item in remoteItems) getId(item): item,
    };

    final Set<String> allIds = <String>{...localById.keys, ...remoteById.keys};

    final List<T> merged = <T>[];

    for (final id in allIds) {
      final T? local = localById[id];
      final T? remote = remoteById[id];

      if (local == null && remote != null) {
        merged.add(remote);
        continue;
      }

      if (local != null && remote == null) {
        final localSync = getSyncMetadata(local);
        if (localSync.status == SyncStatus.pendingDelete) {
          continue;
        }

        merged.add(local);
        continue;
      }

      if (local != null && remote != null) {
        merged.add(resolveConflict(local: local, remote: remote).winner);
      }
    }

    return merged;
  }

  SyncConflictResolution<T> resolveConflict({
    required T local,
    required T remote,
  }) {
    final localSync = getSyncMetadata(local);

    if (localSync.status == SyncStatus.pendingDelete) {
      return SyncConflictResolution<T>(
        winner: local,
        local: local,
        remote: remote,
        outcome: SyncConflictOutcome.localPendingDelete,
      );
    }

    if (localSync.status == SyncStatus.pendingUpload) {
      return SyncConflictResolution<T>(
        winner: local,
        local: local,
        remote: remote,
        outcome: SyncConflictOutcome.localPendingUpload,
      );
    }

    if (localSync.status == SyncStatus.pendingUpdate) {
      return SyncConflictResolution<T>(
        winner: local,
        local: local,
        remote: remote,
        outcome: SyncConflictOutcome.localPendingUpdate,
      );
    }

    final localUpdatedAt = getUpdatedAt(local);
    final remoteUpdatedAt = getUpdatedAt(remote);

    if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return SyncConflictResolution<T>(
        winner: remote,
        local: local,
        remote: remote,
        outcome: SyncConflictOutcome.remoteNewer,
      );
    }

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return SyncConflictResolution<T>(
        winner: local,
        local: local,
        remote: remote,
        outcome: SyncConflictOutcome.localNewer,
      );
    }

    return SyncConflictResolution<T>(
      winner: local,
      local: local,
      remote: remote,
      outcome: SyncConflictOutcome.sameTimestampPreferLocal,
    );
  }
}
