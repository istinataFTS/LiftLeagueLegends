import '../../data/sync/entity_sync_batch_failure.dart';
import 'exceptions.dart';
import 'failures.dart';
import 'sync_exceptions.dart';
import 'sync_failures.dart';

class RepositoryErrorMapper {
  const RepositoryErrorMapper._();

  static Failure map(Object error) {
    if (error is ValidationException) {
      return ValidationFailure(error.message);
    }

    if (error is MissingUserContextException) {
      return SessionLookupFailure(
        message:
            'no authenticated user in context (operation: ${error.operation})',
      );
    }

    if (error is CacheDatabaseException) {
      return DatabaseFailure(error.message);
    }

    if (error is CacheException) {
      return CacheFailure(error.message);
    }

    if (error is ArgumentError) {
      return ValidationFailure(error.message?.toString() ?? error.toString());
    }

    if (error is NetworkSyncException) {
      return NetworkSyncFailure(error.message);
    }

    if (error is AuthSyncException) {
      return AuthSyncFailure(error.message);
    }

    if (error is RemoteSyncException) {
      return RemoteSyncFailure(error.message);
    }

    if (error is EntitySyncBatchFailure) {
      return BatchSyncFailure(
        message: error.message,
        failedUpsertEntityIds: error.failedUpsertEntityIds,
        failedDeleteEntityIds: error.failedDeleteEntityIds,
      );
    }

    return UnexpectedFailure('Unexpected error: $error');
  }
}
