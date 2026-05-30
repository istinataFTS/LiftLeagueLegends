import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/enums/conflict_resolution_strategy.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

// Sync policy where remote is the source of truth when authenticated.
const _remoteOnPolicy = AppSyncPolicy(
  offlineFirst: true,
  localStoreAcceptsWrites: true,
  remoteIsSourceOfTruthWhenAuthenticated: true,
  conflictResolutionStrategy: ConflictResolutionStrategy.serverWins,
  syncTriggers: [],
);

// Sync policy where remote is NOT the source of truth when authenticated.
const _remoteOffPolicy = AppSyncPolicy(
  offlineFirst: true,
  localStoreAcceptsWrites: true,
  remoteIsSourceOfTruthWhenAuthenticated: false,
  conflictResolutionStrategy: ConflictResolutionStrategy.serverWins,
  syncTriggers: [],
);

const _authenticatedSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

const _migrationPendingSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
  requiresInitialCloudMigration: true,
);

void main() {
  late MockAppSessionRepository mockRepository;
  late AuthenticatedDataSourcePreferenceResolver resolver;

  setUp(() {
    mockRepository = MockAppSessionRepository();
    resolver = AuthenticatedDataSourcePreferenceResolver(
      appSessionRepository: mockRepository,
    );
  });

  group('AuthenticatedDataSourcePreferenceResolver', () {
    group('resolveReadPreference', () {
      test('returns localOnly when session retrieval fails', () async {
        when(() => mockRepository.getCurrentSession()).thenAnswer(
          (_) async => const Left(CacheFailure('session not found')),
        );

        final result = await resolver.resolveReadPreference();

        expect(result, DataSourcePreference.localOnly);
      });

      test(
        'returns remoteThenLocal when authenticated and syncPolicy enables remote',
        () async {
          when(
            () => mockRepository.getCurrentSession(),
          ).thenAnswer((_) async => const Right(_authenticatedSession));
          when(() => mockRepository.syncPolicy).thenReturn(_remoteOnPolicy);

          final result = await resolver.resolveReadPreference();

          expect(result, DataSourcePreference.remoteThenLocal);
        },
      );

      test(
        'returns localOnly when authenticated but syncPolicy disables remote',
        () async {
          when(
            () => mockRepository.getCurrentSession(),
          ).thenAnswer((_) async => const Right(_authenticatedSession));
          when(() => mockRepository.syncPolicy).thenReturn(_remoteOffPolicy);

          final result = await resolver.resolveReadPreference();

          expect(result, DataSourcePreference.localOnly);
        },
      );

      // "returns localOnly for unauthenticated guest session" removed:
      // guest sessions no longer exist.

      test('returns localOnly when initial cloud migration is pending, '
          'even if syncPolicy enables remote', () async {
        when(
          () => mockRepository.getCurrentSession(),
        ).thenAnswer((_) async => const Right(_migrationPendingSession));
        when(() => mockRepository.syncPolicy).thenReturn(_remoteOnPolicy);

        final result = await resolver.resolveReadPreference();

        // Remote is not usable until migration completes — serving local avoids
        // a doomed Supabase round-trip that would surface as an error.
        expect(result, DataSourcePreference.localOnly);
      });
    });
  });
}
