import 'package:dartz/dartz.dart';

import '../../core/config/app_sync_policy.dart';
import '../../core/errors/failures.dart';
import '../entities/app_session.dart';
import '../entities/app_user.dart';
import '../entities/initial_cloud_migration_state.dart';

abstract class AppSessionRepository {
  Future<Either<Failure, AppSession>> getCurrentSession();

  Future<Either<Failure, void>> startAuthenticatedSession(
    AppUser user, {
    bool requiresInitialCloudMigration = true,
  });

  Future<Either<Failure, void>> completeInitialCloudMigration();

  Future<Either<Failure, InitialCloudMigrationState?>>
  getInitialCloudMigrationState();

  Future<Either<Failure, void>> saveInitialCloudMigrationState(
    InitialCloudMigrationState state,
  );

  Future<Either<Failure, void>> clearInitialCloudMigrationState();

  Future<Either<Failure, void>> recordSuccessfulCloudSync(DateTime syncedAt);

  Future<Either<Failure, void>> clearSession();

  AppSyncPolicy get syncPolicy;
}
