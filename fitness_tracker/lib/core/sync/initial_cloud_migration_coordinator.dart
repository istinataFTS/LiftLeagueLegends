import '../../domain/entities/initial_cloud_migration_state.dart';

enum InitialCloudMigrationStatus {
  skipped,
  inProgress,
  completed,

  /// At least one step failed but the remaining steps still ran. The session
  /// is established anyway (the user must never be locked out of their own
  /// account); the migration is intentionally left incomplete so the failed
  /// steps are retried on the next sync and converge later.
  completedWithErrors,

  failed,
}

class InitialCloudMigrationResult {
  final InitialCloudMigrationStatus status;
  final String message;
  final InitialCloudMigrationState? state;

  const InitialCloudMigrationResult({
    required this.status,
    required this.message,
    this.state,
  });
}

abstract class InitialCloudMigrationCoordinator {
  Future<InitialCloudMigrationResult> runIfRequired();
}
