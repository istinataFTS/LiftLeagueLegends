import 'failures.dart';

/// Failure produced when sync fails due to network unavailability.
class NetworkSyncFailure extends Failure {
  const NetworkSyncFailure(super.message);
}

/// Failure produced when sync fails due to an authentication
/// or authorization issue.
class AuthSyncFailure extends Failure {
  const AuthSyncFailure(super.message);
}

/// Failure produced when sync fails at the remote backend level.
class RemoteSyncFailure extends Failure {
  const RemoteSyncFailure(super.message);
}

/// Failure produced when a batch sync operation partially or fully fails.
/// Carries the IDs of entities that could not be upserted or deleted,
/// allowing callers to reason about partial failures without string parsing.
class BatchSyncFailure extends Failure {
  final List<String> failedUpsertEntityIds;
  final List<String> failedDeleteEntityIds;

  const BatchSyncFailure({
    required String message,
    this.failedUpsertEntityIds = const <String>[],
    this.failedDeleteEntityIds = const <String>[],
  }) : super(message);

  bool get hasUpsertFailures => failedUpsertEntityIds.isNotEmpty;
  bool get hasDeleteFailures => failedDeleteEntityIds.isNotEmpty;

  @override
  List<Object> get props => [
    message,
    failedUpsertEntityIds,
    failedDeleteEntityIds,
  ];
}
