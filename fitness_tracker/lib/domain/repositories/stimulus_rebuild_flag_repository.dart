/// Persisted one-shot flag that signals a pending `muscle_stimulus` rebuild.
///
/// Set by the v26 DB migration; consumed once at the next launch by
/// `RunPendingStimulusRebuild` so the derived projection is regenerated even
/// when remote sync (and its post-sync rebuild hook) cannot run — e.g. an
/// offline launch immediately after the upgrade.
abstract class StimulusRebuildFlagRepository {
  /// Whether a rebuild is currently pending.
  Future<bool> isPending();

  /// Clears the flag after a successful rebuild.
  Future<void> clear();
}
