import 'package:dartz/dartz.dart';

import '../../core/config/app_sync_policy.dart';
import '../../core/constants/app_metadata_keys.dart';
import '../../core/enums/auth_mode.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../domain/entities/app_session.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/initial_cloud_migration_state.dart';
import '../../domain/repositories/app_session_repository.dart';
import '../datasources/local/app_metadata_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';

class AppSessionRepositoryImpl implements AppSessionRepository {
  static const String _authModeKey = 'session.auth_mode';
  static const String _userKey = 'session.user';
  static const String _requiresInitialMigrationKey =
      'session.requires_initial_cloud_migration';
  static const String _lastCloudSyncAtKey = 'session.last_cloud_sync_at';

  final AppMetadataLocalDataSource localDataSource;
  final AuthRemoteDataSource authRemoteDataSource;
  final AppSyncPolicy _syncPolicy;

  const AppSessionRepositoryImpl({
    required this.localDataSource,
    required this.authRemoteDataSource,
    AppSyncPolicy syncPolicy = AppSyncPolicy.productionDefault,
  }) : _syncPolicy = syncPolicy;

  @override
  AppSyncPolicy get syncPolicy => _syncPolicy;

  @override
  Future<Either<Failure, AppSession>> getCurrentSession() {
    return RepositoryGuard.run(() async {
      final authModeValue = await localDataSource.readString(_authModeKey);
      final userJson = await localDataSource.readJsonObject(_userKey);
      final requiresInitialMigration =
          await localDataSource.readBool(_requiresInitialMigrationKey) ?? false;
      final lastCloudSyncAt = await localDataSource.readDateTime(
        _lastCloudSyncAtKey,
      );

      final localAuthMode = authModeValue == AuthMode.authenticated.name
          ? AuthMode.authenticated
          : AuthMode.guest;

      AppUser? localUser;
      if (userJson != null) {
        localUser = AppUser(
          id: userJson['id'] as String,
          email: userJson['email'] as String,
          displayName: userJson['displayName'] as String?,
        );
      }

      if (authRemoteDataSource.isConfigured) {
        final remoteUser = await authRemoteDataSource.getCurrentUser();

        if (remoteUser != null) {
          return AppSession(
            authMode: AuthMode.authenticated,
            user: remoteUser,
            requiresInitialCloudMigration: requiresInitialMigration,
            lastCloudSyncAt: lastCloudSyncAt,
          );
        }

        if (localAuthMode == AuthMode.authenticated) {
          return const AppSession.guest();
        }
      }

      if (localAuthMode == AuthMode.authenticated && localUser == null) {
        return const AppSession.guest();
      }

      return AppSession(
        authMode: localAuthMode,
        user: localUser,
        requiresInitialCloudMigration: requiresInitialMigration,
        lastCloudSyncAt: lastCloudSyncAt,
      );
    });
  }

  @override
  Future<Either<Failure, void>> startGuestSession() {
    return RepositoryGuard.run(() async {
      await localDataSource.writeString(_authModeKey, AuthMode.guest.name);
      await localDataSource.delete(_userKey);
      await localDataSource.writeBool(_requiresInitialMigrationKey, false);
      await localDataSource.delete(_lastCloudSyncAtKey);
      await localDataSource.delete(AppMetadataKeys.currentAuthenticatedUserId);
      await localDataSource.delete(
        AppMetadataKeys.initialCloudMigrationCompleted,
      );
      await localDataSource.delete(
        AppMetadataKeys.initialCloudMigrationCompletedAt,
      );
      await clearInitialCloudMigrationState();
    });
  }

  @override
  Future<Either<Failure, void>> startAuthenticatedSession(
    AppUser user, {
    bool requiresInitialCloudMigration = true,
  }) {
    return RepositoryGuard.run(() async {
      await localDataSource.writeString(
        _authModeKey,
        AuthMode.authenticated.name,
      );
      await localDataSource.writeJsonObject(_userKey, <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
      });
      await localDataSource.writeBool(
        _requiresInitialMigrationKey,
        requiresInitialCloudMigration,
      );
      await localDataSource.writeString(
        AppMetadataKeys.currentAuthenticatedUserId,
        user.id,
      );

      if (requiresInitialCloudMigration) {
        await localDataSource.delete(
          AppMetadataKeys.initialCloudMigrationCompleted,
        );
        await localDataSource.delete(
          AppMetadataKeys.initialCloudMigrationCompletedAt,
        );
      } else {
        await clearInitialCloudMigrationState();
      }
    });
  }

  @override
  Future<Either<Failure, void>> completeInitialCloudMigration() {
    return RepositoryGuard.run(() async {
      await localDataSource.writeBool(_requiresInitialMigrationKey, false);
      await localDataSource.writeBool(
        AppMetadataKeys.initialCloudMigrationCompleted,
        true,
      );
      await localDataSource.writeDateTime(
        AppMetadataKeys.initialCloudMigrationCompletedAt,
        DateTime.now(),
      );
      await clearInitialCloudMigrationState();
    });
  }

  @override
  Future<Either<Failure, InitialCloudMigrationState?>>
  getInitialCloudMigrationState() {
    return RepositoryGuard.run(() async {
      final json = await localDataSource.readJsonObject(
        AppMetadataKeys.initialCloudMigrationState,
      );

      if (json == null) {
        return null;
      }

      return InitialCloudMigrationState.fromJson(json);
    });
  }

  @override
  Future<Either<Failure, void>> saveInitialCloudMigrationState(
    InitialCloudMigrationState state,
  ) {
    return RepositoryGuard.run(() async {
      await localDataSource.writeJsonObject(
        AppMetadataKeys.initialCloudMigrationState,
        state.toJson(),
      );
    });
  }

  @override
  Future<Either<Failure, void>> clearInitialCloudMigrationState() {
    return RepositoryGuard.run(() async {
      await localDataSource.delete(AppMetadataKeys.initialCloudMigrationState);
    });
  }

  @override
  Future<Either<Failure, void>> recordSuccessfulCloudSync(DateTime syncedAt) {
    return RepositoryGuard.run(() async {
      await localDataSource.writeDateTime(_lastCloudSyncAtKey, syncedAt);
    });
  }

  @override
  Future<Either<Failure, void>> clearSession() {
    return RepositoryGuard.run(() async {
      await localDataSource.delete(_authModeKey);
      await localDataSource.delete(_userKey);
      await localDataSource.delete(_requiresInitialMigrationKey);
      await localDataSource.delete(_lastCloudSyncAtKey);
      await localDataSource.delete(AppMetadataKeys.currentAuthenticatedUserId);
      await localDataSource.delete(
        AppMetadataKeys.initialCloudMigrationCompleted,
      );
      await localDataSource.delete(
        AppMetadataKeys.initialCloudMigrationCompletedAt,
      );
      await clearInitialCloudMigrationState();
    });
  }
}
