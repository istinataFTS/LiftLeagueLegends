import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/constants/app_metadata_keys.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/app_metadata_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/auth_remote_datasource.dart';
import 'package:fitness_tracker/data/repositories/app_session_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/initial_cloud_migration_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppMetadataLocalDataSource extends Mock
    implements AppMetadataLocalDataSource {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockAppMetadataLocalDataSource localDataSource;
  late MockAuthRemoteDataSource authRemoteDataSource;
  late AppSessionRepositoryImpl repository;

  const AppUser user = AppUser(
    id: 'user-1',
    email: 'user@test.com',
    displayName: 'Marin',
  );

  final DateTime baseDate = DateTime(2026, 3, 26, 10, 0);

  setUp(() {
    localDataSource = MockAppMetadataLocalDataSource();
    authRemoteDataSource = MockAuthRemoteDataSource();

    repository = AppSessionRepositoryImpl(
      localDataSource: localDataSource,
      authRemoteDataSource: authRemoteDataSource,
      syncPolicy: AppSyncPolicy.productionDefault,
    );

    when(() => authRemoteDataSource.isConfigured).thenReturn(false);
    when(
      () => localDataSource.writeString(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => localDataSource.writeBool(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => localDataSource.writeDateTime(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => localDataSource.writeJsonObject(any(), any()),
    ).thenAnswer((_) async {});
    when(() => localDataSource.delete(any())).thenAnswer((_) async {});
  });

  group('AppSessionRepositoryImpl.getCurrentSession', () {
    test('returns guest session from empty local metadata', () async {
      when(
        () => localDataSource.readString(any()),
      ).thenAnswer((_) async => null);
      when(
        () => localDataSource.readJsonObject(any()),
      ).thenAnswer((_) async => null);
      when(() => localDataSource.readBool(any())).thenAnswer((_) async => null);
      when(
        () => localDataSource.readDateTime(any()),
      ).thenAnswer((_) async => null);

      final Either<Failure, AppSession> result = await repository
          .getCurrentSession();

      // Post guest-removal: an empty local metadata snapshot yields a
      // SessionLookupFailure rather than a sentinel guest session.
      expect(result.isLeft(), isTrue);
    });

    test(
      'returns authenticated local session when remote auth is disabled',
      () async {
        when(
          () => localDataSource.readString('session.auth_mode'),
        ).thenAnswer((_) async => 'authenticated');
        when(() => localDataSource.readJsonObject('session.user')).thenAnswer(
          (_) async => <String, dynamic>{
            'id': user.id,
            'email': user.email,
            'displayName': user.displayName,
          },
        );
        when(
          () => localDataSource.readBool(
            'session.requires_initial_cloud_migration',
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localDataSource.readDateTime('session.last_cloud_sync_at'),
        ).thenAnswer((_) async => baseDate);

        final Either<Failure, AppSession> result = await repository
            .getCurrentSession();

        expect(
          result,
          Right<Failure, AppSession>(
            AppSession(
              user: user,
              requiresInitialCloudMigration: true,
              lastCloudSyncAt: baseDate,
            ),
          ),
        );
      },
    );

    test(
      'prefers remote authenticated user when remote auth is configured',
      () async {
        when(() => authRemoteDataSource.isConfigured).thenReturn(true);
        when(
          () => authRemoteDataSource.getCurrentUser(),
        ).thenAnswer((_) async => user);
        when(
          () => localDataSource.readString('session.auth_mode'),
        ).thenAnswer((_) async => 'guest');
        when(
          () => localDataSource.readJsonObject('session.user'),
        ).thenAnswer((_) async => null);
        when(
          () => localDataSource.readBool(
            'session.requires_initial_cloud_migration',
          ),
        ).thenAnswer((_) async => true);
        when(
          () => localDataSource.readDateTime('session.last_cloud_sync_at'),
        ).thenAnswer((_) async => baseDate);

        final Either<Failure, AppSession> result = await repository
            .getCurrentSession();

        expect(
          result,
          Right<Failure, AppSession>(
            AppSession(
              user: user,
              requiresInitialCloudMigration: true,
              lastCloudSyncAt: baseDate,
            ),
          ),
        );
      },
    );

    test(
      'returns SessionLookupFailure when remote is configured but signed out',
      () async {
        when(() => authRemoteDataSource.isConfigured).thenReturn(true);
        when(
          () => authRemoteDataSource.getCurrentUser(),
        ).thenAnswer((_) async => null);
        when(
          () => localDataSource.readString(any()),
        ).thenAnswer((_) async => null);
        when(() => localDataSource.readJsonObject('session.user')).thenAnswer(
          (_) async => <String, dynamic>{'id': user.id, 'email': user.email},
        );
        when(
          () => localDataSource.readBool(any()),
        ).thenAnswer((_) async => false);
        when(
          () => localDataSource.readDateTime(any()),
        ).thenAnswer((_) async => null);

        final Either<Failure, AppSession> result = await repository
            .getCurrentSession();

        // Post guest-removal: a remote-configured app with no remote user
        // surfaces as a SessionLookupFailure rather than a guest fallback.
        expect(result.isLeft(), isTrue);
      },
    );
  });

  group('AppSessionRepositoryImpl session transitions', () {
    // startGuestSession test removed: guest sessions no longer exist.

    test(
      'startAuthenticatedSession persists user and migration-required state',
      () async {
        final Either<Failure, void> result = await repository
            .startAuthenticatedSession(
              user,
              requiresInitialCloudMigration: true,
            );

        expect(result.isRight(), isTrue);
        verify(
          () =>
              localDataSource.writeJsonObject('session.user', <String, dynamic>{
                'id': user.id,
                'email': user.email,
                'displayName': user.displayName,
              }),
        ).called(1);
        verify(
          () => localDataSource.writeBool(
            'session.requires_initial_cloud_migration',
            true,
          ),
        ).called(1);
        verify(
          () => localDataSource.writeString(
            AppMetadataKeys.currentAuthenticatedUserId,
            user.id,
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationCompleted,
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationCompletedAt,
          ),
        ).called(1);
      },
    );

    test(
      'startAuthenticatedSession clears migration state when migration is not required',
      () async {
        final Either<Failure, void> result = await repository
            .startAuthenticatedSession(
              user,
              requiresInitialCloudMigration: false,
            );

        expect(result.isRight(), isTrue);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationState,
          ),
        ).called(1);
      },
    );

    test(
      'completeInitialCloudMigration updates completion markers and clears state',
      () async {
        final Either<Failure, void> result = await repository
            .completeInitialCloudMigration();

        expect(result.isRight(), isTrue);
        verify(
          () => localDataSource.writeBool(
            'session.requires_initial_cloud_migration',
            false,
          ),
        ).called(1);
        verify(
          () => localDataSource.writeBool(
            AppMetadataKeys.initialCloudMigrationCompleted,
            true,
          ),
        ).called(1);
        verify(
          () => localDataSource.writeDateTime(
            AppMetadataKeys.initialCloudMigrationCompletedAt,
            any(),
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationState,
          ),
        ).called(1);
      },
    );

    test(
      'clearSession removes only local session state and does not call remote signOut',
      () async {
        final Either<Failure, void> result = await repository.clearSession();

        expect(result.isRight(), isTrue);
        verifyNever(() => authRemoteDataSource.signOut());
        verify(() => localDataSource.delete('session.user')).called(1);
        verify(
          () => localDataSource.delete(
            'session.requires_initial_cloud_migration',
          ),
        ).called(1);
        verify(
          () => localDataSource.delete('session.last_cloud_sync_at'),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.currentAuthenticatedUserId,
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationCompleted,
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationCompletedAt,
          ),
        ).called(1);
        verify(
          () => localDataSource.delete(
            AppMetadataKeys.initialCloudMigrationState,
          ),
        ).called(1);
      },
    );
  });

  group('AppSessionRepositoryImpl migration state', () {
    test(
      'save and read initial cloud migration state round-trip through metadata',
      () async {
        final InitialCloudMigrationState state = InitialCloudMigrationState(
          userId: user.id,
          mealsCompleted: true,
          nutritionLogsCompleted: false,
          startedAt: baseDate,
          updatedAt: baseDate,
        );

        when(
          () => localDataSource.readJsonObject(
            AppMetadataKeys.initialCloudMigrationState,
          ),
        ).thenAnswer((_) async => state.toJson());

        final saveResult = await repository.saveInitialCloudMigrationState(
          state,
        );
        final readResult = await repository.getInitialCloudMigrationState();

        expect(saveResult.isRight(), isTrue);
        verify(
          () => localDataSource.writeJsonObject(
            AppMetadataKeys.initialCloudMigrationState,
            state.toJson(),
          ),
        ).called(1);

        expect(readResult, Right<Failure, InitialCloudMigrationState?>(state));
      },
    );

    test(
      'recordSuccessfulCloudSync stores last cloud sync timestamp',
      () async {
        final Either<Failure, void> result = await repository
            .recordSuccessfulCloudSync(baseDate);

        expect(result.isRight(), isTrue);
        verify(
          () => localDataSource.writeDateTime(
            'session.last_cloud_sync_at',
            baseDate,
          ),
        ).called(1);
      },
    );
  });
}
