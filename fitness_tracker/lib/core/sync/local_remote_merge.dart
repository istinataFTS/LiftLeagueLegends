import '../../domain/entities/entity_sync_metadata.dart';
import 'entity_sync_resolver.dart';
import 'sync_conflict_resolution.dart';

typedef EntityIdGetter<T> = String Function(T entity);
typedef EntityUpdatedAtGetter<T> = DateTime Function(T entity);
typedef EntitySyncMetadataGetter<T> = EntitySyncMetadata Function(T entity);

class LocalRemoteMerge<T> {
  final EntitySyncResolver<T> _resolver;

  LocalRemoteMerge({
    required EntityIdGetter<T> getId,
    required EntityUpdatedAtGetter<T> getUpdatedAt,
    required EntitySyncMetadataGetter<T> getSyncMetadata,
  }) : _resolver = EntitySyncResolver<T>(
         getId: getId,
         getUpdatedAt: getUpdatedAt,
         getSyncMetadata: getSyncMetadata,
       );

  List<T> mergeLists({
    required List<T> localItems,
    required List<T> remoteItems,
  }) {
    return _resolver.mergeLists(
      localItems: localItems,
      remoteItems: remoteItems,
    );
  }

  T chooseWinner({required T local, required T remote}) {
    return _resolver.resolveConflict(local: local, remote: remote).winner;
  }

  SyncConflictResolution<T> resolveConflict({
    required T local,
    required T remote,
  }) {
    return _resolver.resolveConflict(local: local, remote: remote);
  }
}
