import '../../../core/enums/sync_entity_type.dart';
import '../../../domain/entities/pending_sync_delete.dart';

abstract class PendingSyncDeleteLocalDataSource {
  Future<void> enqueue(PendingSyncDelete operation);

  Future<List<PendingSyncDelete>> getPendingByEntityType(
    SyncEntityType entityType,
  );

  Future<void> markAttempted(
    String operationId, {
    required DateTime attemptedAt,
    String? errorMessage,
  });

  Future<void> remove(String operationId);

  Future<void> clearAll();
}
