/// A runner for push (upload) operations — no parameters needed because the
/// coordinator already knows which entities are pending.
typedef SyncPushRunner = Future<void> Function();

/// A runner for pull (download) operations.
///
/// [userId] — the authenticated user whose remote rows to fetch.
/// [since]  — only fetch rows modified after this timestamp; null means fetch
///            all rows (used on initial re-login when local is empty).
typedef SyncPullRunner = Future<void> Function(String userId, DateTime? since);

class SyncFeature {
  final String name;

  /// Uploads all locally pending changes to the remote store.
  final SyncPushRunner syncPendingChanges;

  /// Downloads remote changes into the local store, respecting the
  /// local-wins conflict rule for dirty (pending) entities.
  final SyncPullRunner pullRemoteChanges;

  const SyncFeature({
    required this.name,
    required this.syncPendingChanges,
    required this.pullRemoteChanges,
  });
}

class SyncFeatureRunResult {
  final String featureName;
  final bool isSuccess;
  final String? errorMessage;

  const SyncFeatureRunResult({
    required this.featureName,
    required this.isSuccess,
    this.errorMessage,
  });

  const SyncFeatureRunResult.success(String featureName)
    : featureName = featureName,
      isSuccess = true,
      errorMessage = null;

  const SyncFeatureRunResult.failure({
    required this.featureName,
    required this.errorMessage,
  }) : isSuccess = false;
}
