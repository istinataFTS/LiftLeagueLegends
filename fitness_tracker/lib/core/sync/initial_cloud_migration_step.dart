/// Runs one initial cloud migration step for the authenticated user identified
/// by [userId]. Implementations may prepare local data, upload pending changes,
/// or both, but must remain safe to rerun.
typedef InitialCloudMigrationRunner = Future<void> Function(String userId);

class InitialCloudMigrationStep {
  final String key;
  final InitialCloudMigrationRunner run;

  const InitialCloudMigrationStep({required this.key, required this.run});
}
