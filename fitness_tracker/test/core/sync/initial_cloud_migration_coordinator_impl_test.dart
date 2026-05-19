import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/sync/initial_cloud_migration_coordinator.dart';
import 'package:fitness_tracker/core/sync/initial_cloud_migration_coordinator_impl.dart';
import 'package:fitness_tracker/core/sync/initial_cloud_migration_step.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/initial_cloud_migration_state.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      InitialCloudMigrationState(
        userId: 'fallback-user',
        startedAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  late MockAppSessionRepository repository;
  late InitialCloudMigrationCoordinator coordinator;
  late List<String> executionLog;

  const AppUser user = AppUser(id: 'user-1', email: 'user@test.com');

  AppSession authenticatedSession({bool requiresInitialCloudMigration = true}) {
    return AppSession(
      authMode: AuthMode.authenticated,
      user: user,
      requiresInitialCloudMigration: requiresInitialCloudMigration,
    );
  }

  setUp(() {
    repository = MockAppSessionRepository();
    executionLog = <String>[];

    when(
      () => repository.syncPolicy,
    ).thenReturn(AppSyncPolicy.productionDefault);

    when(
      () => repository.saveInitialCloudMigrationState(any()),
    ).thenAnswer((_) async => const Right(null));

    when(
      () => repository.completeInitialCloudMigration(),
    ).thenAnswer((_) async => const Right(null));

    when(
      () => repository.clearInitialCloudMigrationState(),
    ).thenAnswer((_) async => const Right(null));

    coordinator = InitialCloudMigrationCoordinatorImpl(
      appSessionRepository: repository,
      steps: <InitialCloudMigrationStep>[
        InitialCloudMigrationStep(
          key: 'meals',
          run: (userId) async {
            executionLog.add('meals:$userId');
          },
        ),
        InitialCloudMigrationStep(
          key: 'nutrition_logs',
          run: (userId) async {
            executionLog.add('nutrition_logs:$userId');
          },
        ),
      ],
    );
  });

  test('skips when session is guest', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => const Right(AppSession.guest()));

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.skipped);
    expect(executionLog, isEmpty);
    verifyNever(() => repository.getInitialCloudMigrationState());
  });

  test('skips when migration is already completed', () async {
    when(() => repository.getCurrentSession()).thenAnswer(
      (_) async =>
          Right(authenticatedSession(requiresInitialCloudMigration: false)),
    );

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.skipped);
    expect(executionLog, isEmpty);
    verifyNever(() => repository.getInitialCloudMigrationState());
  });

  test('runs all steps and completes migration', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));
    when(
      () => repository.getInitialCloudMigrationState(),
    ).thenAnswer((_) async => const Right(null));

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.completed);
    expect(executionLog, <String>['meals:user-1', 'nutrition_logs:user-1']);
    verify(
      () => repository.saveInitialCloudMigrationState(any()),
    ).called(greaterThanOrEqualTo(3));
    verify(() => repository.completeInitialCloudMigration()).called(1);
  });

  test('resumes from existing partial state', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));
    when(() => repository.getInitialCloudMigrationState()).thenAnswer(
      (_) async => Right(
        InitialCloudMigrationState(
          userId: 'user-1',
          mealsCompleted: true,
          nutritionLogsCompleted: false,
          startedAt: DateTime(2026, 3, 20),
          updatedAt: DateTime(2026, 3, 20),
        ),
      ),
    );

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.completed);
    expect(executionLog, <String>['nutrition_logs:user-1']);
    verify(() => repository.completeInitialCloudMigration()).called(1);
  });

  test('resets migration state when authenticated user changes', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));
    when(() => repository.getInitialCloudMigrationState()).thenAnswer(
      (_) async => Right(
        InitialCloudMigrationState(
          userId: 'another-user',
          mealsCompleted: true,
          nutritionLogsCompleted: true,
          startedAt: DateTime(2026, 3, 20),
          updatedAt: DateTime(2026, 3, 20),
        ),
      ),
    );

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.completed);
    expect(executionLog, <String>['meals:user-1', 'nutrition_logs:user-1']);
  });

  test('passes authenticated user id into migration steps', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));
    when(
      () => repository.getInitialCloudMigrationState(),
    ).thenAnswer((_) async => const Right(null));

    await coordinator.runIfRequired();

    expect(executionLog, everyElement(contains('user-1')));
  });

  test('a failed step is non-fatal: continues, reports completedWithErrors, '
      'and leaves the migration incomplete for retry', () async {
    coordinator = InitialCloudMigrationCoordinatorImpl(
      appSessionRepository: repository,
      steps: <InitialCloudMigrationStep>[
        InitialCloudMigrationStep(
          key: 'meals',
          run: (userId) async {
            executionLog.add('meals:$userId');
          },
        ),
        InitialCloudMigrationStep(
          key: 'nutrition_logs',
          run: (userId) async {
            throw StateError('boom');
          },
        ),
        InitialCloudMigrationStep(
          key: 'workout_sets',
          run: (userId) async {
            executionLog.add('workout_sets:$userId');
          },
        ),
      ],
    );

    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));
    when(
      () => repository.getInitialCloudMigrationState(),
    ).thenAnswer((_) async => const Right(null));

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.completedWithErrors);
    expect(result.message, contains('nutrition_logs'));
    // The step after the failing one still ran (continue-on-failure).
    expect(executionLog, <String>['meals:user-1', 'workout_sets:user-1']);
    // Migration must NOT be marked complete, so the next sync retries it.
    verifyNever(() => repository.completeInitialCloudMigration());
    verify(
      () => repository.saveInitialCloudMigrationState(any()),
    ).called(greaterThanOrEqualTo(2));
  });

  test('fails when session lookup fails', () async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => const Left(CacheFailure('session unavailable')));

    final result = await coordinator.runIfRequired();

    expect(result.status, InitialCloudMigrationStatus.failed);
    expect(result.message, contains('session lookup failed'));
  });
}
