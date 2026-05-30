import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/enums/sync_trigger.dart';
import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/core/sync/initial_cloud_migration_coordinator.dart';
import 'package:fitness_tracker/core/sync/post_sync_hook.dart';
import 'package:fitness_tracker/core/sync/remote_sync_availability.dart';
import 'package:fitness_tracker/core/sync/remote_sync_runtime_policy.dart';
import 'package:fitness_tracker/core/sync/sync_feature.dart';
import 'package:fitness_tracker/core/sync/sync_orchestrator.dart';
import 'package:fitness_tracker/core/sync/sync_orchestrator_impl.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockNetworkStatusService extends Mock implements NetworkStatusService {}

class MockInitialCloudMigrationCoordinator extends Mock
    implements InitialCloudMigrationCoordinator {}

/// A [PostSyncHook] that simply records every invocation. Lets tests
/// assert ordering and which contexts were passed without reaching for
/// mocks.
class _RecordingHook implements PostSyncHook {
  _RecordingHook({
    required this.name,
    required this.triggeringFeatures,
    this.shouldThrow = false,
  });

  @override
  final String name;

  @override
  final Set<String> triggeringFeatures;

  final bool shouldThrow;

  final List<PostSyncContext> invocations = <PostSyncContext>[];

  @override
  Future<void> run(PostSyncContext context) async {
    invocations.add(context);
    if (shouldThrow) {
      throw StateError('hook $name intentionally threw');
    }
  }
}

void main() {
  late MockAppSessionRepository repository;
  late MockNetworkStatusService networkStatusService;
  late MockInitialCloudMigrationCoordinator migrationCoordinator;

  const runtimePolicy = RemoteSyncRuntimePolicy(
    isSupabaseEnabled: true,
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
  );

  AppSession authenticatedSession({
    bool requiresInitialCloudMigration = false,
  }) {
    return AppSession(
      user: const AppUser(id: 'user-1', email: 'user@test.com'),
      requiresInitialCloudMigration: requiresInitialCloudMigration,
    );
  }

  SyncOrchestratorImpl buildOrchestrator({
    required List<PostSyncHook> hooks,
    List<SyncFeature>? features,
  }) {
    return SyncOrchestratorImpl(
      appSessionRepository: repository,
      syncPolicy: AppSyncPolicy.productionDefault,
      remoteSyncAvailability: RemoteSyncAvailability(
        runtimePolicy: runtimePolicy,
        networkStatusService: networkStatusService,
      ),
      initialCloudMigrationCoordinator: migrationCoordinator,
      features:
          features ??
          <SyncFeature>[
            SyncFeature(
              name: 'exercises',
              syncPendingChanges: () async {},
              pullRemoteChanges: (_, __) async {},
            ),
            SyncFeature(
              name: 'workout_sets',
              syncPendingChanges: () async {},
              pullRemoteChanges: (_, __) async {},
            ),
          ],
      postSyncHooks: hooks,
    );
  }

  setUp(() {
    repository = MockAppSessionRepository();
    networkStatusService = MockNetworkStatusService();
    migrationCoordinator = MockInitialCloudMigrationCoordinator();

    when(
      () => repository.syncPolicy,
    ).thenReturn(AppSyncPolicy.productionDefault);
    when(
      () => repository.recordSuccessfulCloudSync(any()),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => networkStatusService.isNetworkAvailable(),
    ).thenAnswer((_) async => true);
    when(() => migrationCoordinator.runIfRequired()).thenAnswer(
      (_) async => const InitialCloudMigrationResult(
        status: InitialCloudMigrationStatus.completed,
        message: 'initial cloud migration completed successfully',
      ),
    );
  });

  group('feature sync', () {
    test('runs hooks in registration order after a successful pull, with the '
        'correct pulledFeatures set', () async {
      final factorHook = _RecordingHook(
        name: 'factor_heal',
        triggeringFeatures: const {'exercises'},
      );
      final stimulusHook = _RecordingHook(
        name: 'stimulus_rebuild',
        triggeringFeatures: const {'exercises', 'workout_sets'},
      );

      final orchestrator = buildOrchestrator(
        hooks: <PostSyncHook>[factorHook, stimulusHook],
      );

      when(
        () => repository.getCurrentSession(),
      ).thenAnswer((_) async => Right(authenticatedSession()));

      final result = await orchestrator.run(SyncTrigger.appLaunch);

      expect(result.status, SyncRunStatus.completed);
      expect(factorHook.invocations, hasLength(1));
      expect(stimulusHook.invocations, hasLength(1));
      expect(
        factorHook.invocations.single.pulledFeatures,
        equals(<String>{'exercises', 'workout_sets'}),
      );
      expect(factorHook.invocations.single.userId, 'user-1');
      expect(factorHook.invocations.single.trigger, SyncTrigger.appLaunch);
    });

    test('skips hooks whose triggering features were not pulled', () async {
      final unrelatedHook = _RecordingHook(
        name: 'meals_projection',
        triggeringFeatures: const {'meals'},
      );

      final orchestrator = buildOrchestrator(
        hooks: <PostSyncHook>[unrelatedHook],
        features: <SyncFeature>[
          SyncFeature(
            name: 'exercises',
            syncPendingChanges: () async {},
            pullRemoteChanges: (_, __) async {},
          ),
        ],
      );

      when(
        () => repository.getCurrentSession(),
      ).thenAnswer((_) async => Right(authenticatedSession()));

      await orchestrator.run(SyncTrigger.appLaunch);

      expect(unrelatedHook.invocations, isEmpty);
    });

    test(
      'runs always-run hooks (empty triggeringFeatures) unconditionally',
      () async {
        final alwaysHook = _RecordingHook(
          name: 'always',
          triggeringFeatures: const <String>{},
        );

        final orchestrator = buildOrchestrator(
          hooks: <PostSyncHook>[alwaysHook],
          features: <SyncFeature>[
            SyncFeature(
              name: 'targets',
              syncPendingChanges: () async {},
              pullRemoteChanges: (_, __) async {},
            ),
          ],
        );

        when(
          () => repository.getCurrentSession(),
        ).thenAnswer((_) async => Right(authenticatedSession()));

        await orchestrator.run(SyncTrigger.appLaunch);

        expect(alwaysHook.invocations, hasLength(1));
      },
    );

    test('runs hooks for successfully-pulled features even when a feature '
        'push fails', () async {
      final hook = _RecordingHook(
        name: 'factor_heal',
        triggeringFeatures: const {'exercises'},
      );

      final orchestrator = buildOrchestrator(
        hooks: <PostSyncHook>[hook],
        features: <SyncFeature>[
          SyncFeature(
            name: 'exercises',
            // Pull succeeds, push fails.
            syncPendingChanges: () async => throw StateError('boom'),
            pullRemoteChanges: (_, __) async {},
          ),
        ],
      );

      when(
        () => repository.getCurrentSession(),
      ).thenAnswer((_) async => Right(authenticatedSession()));

      final result = await orchestrator.run(SyncTrigger.appLaunch);

      // The push failure marks the run failed...
      expect(result.status, SyncRunStatus.failed);
      // ...but 'exercises' pulled successfully, so its post-sync hook
      // still runs. Derived local projections (muscle factors, stimulus)
      // must not be left stale just because an unrelated push was
      // rejected by the server.
      expect(hook.invocations, hasLength(1));
    });

    test(
      'does not include a feature in pulledFeatures if its pull threw',
      () async {
        final hook = _RecordingHook(
          name: 'factor_heal',
          triggeringFeatures: const {'exercises'},
        );

        final orchestrator = buildOrchestrator(
          hooks: <PostSyncHook>[hook],
          features: <SyncFeature>[
            SyncFeature(
              name: 'exercises',
              syncPendingChanges: () async {},
              pullRemoteChanges: (_, __) async => throw StateError('no pull'),
            ),
            SyncFeature(
              name: 'workout_sets',
              syncPendingChanges: () async {},
              pullRemoteChanges: (_, __) async {},
            ),
          ],
        );

        when(
          () => repository.getCurrentSession(),
        ).thenAnswer((_) async => Right(authenticatedSession()));

        final result = await orchestrator.run(SyncTrigger.appLaunch);

        // Feature sync failed overall (exercises threw), so hooks must not
        // run — asserting both properties in one test keeps the contract
        // easy to read.
        expect(result.status, SyncRunStatus.failed);
        expect(hook.invocations, isEmpty);
      },
    );

    test('a throwing hook does not downgrade the sync result and does not '
        'prevent later hooks from running', () async {
      final failingHook = _RecordingHook(
        name: 'failing',
        triggeringFeatures: const {'exercises'},
        shouldThrow: true,
      );
      final followingHook = _RecordingHook(
        name: 'following',
        triggeringFeatures: const {'exercises'},
      );

      final orchestrator = buildOrchestrator(
        hooks: <PostSyncHook>[failingHook, followingHook],
      );

      when(
        () => repository.getCurrentSession(),
      ).thenAnswer((_) async => Right(authenticatedSession()));

      final result = await orchestrator.run(SyncTrigger.appLaunch);

      expect(result.status, SyncRunStatus.completed);
      expect(followingHook.invocations, hasLength(1));
    });
  });

  group('initial cloud migration', () {
    test(
      'runs every hook after a completed migration with every feature marked '
      'as pulled',
      () async {
        final factorHook = _RecordingHook(
          name: 'factor_heal',
          triggeringFeatures: const {'exercises'},
        );
        final stimulusHook = _RecordingHook(
          name: 'stimulus_rebuild',
          triggeringFeatures: const {'exercises', 'workout_sets'},
        );

        final orchestrator = buildOrchestrator(
          hooks: <PostSyncHook>[factorHook, stimulusHook],
        );

        when(() => repository.getCurrentSession()).thenAnswer(
          (_) async =>
              Right(authenticatedSession(requiresInitialCloudMigration: true)),
        );

        final result = await orchestrator.run(SyncTrigger.initialSignIn);

        expect(result.status, SyncRunStatus.completed);
        expect(factorHook.invocations, hasLength(1));
        expect(stimulusHook.invocations, hasLength(1));
        expect(
          factorHook.invocations.single.pulledFeatures,
          equals(<String>{'exercises', 'workout_sets'}),
        );
      },
    );

    test('does not run hooks when the initial migration fails', () async {
      final hook = _RecordingHook(
        name: 'factor_heal',
        triggeringFeatures: const {'exercises'},
      );

      when(() => migrationCoordinator.runIfRequired()).thenAnswer(
        (_) async => const InitialCloudMigrationResult(
          status: InitialCloudMigrationStatus.failed,
          message: 'step workout_sets failed',
        ),
      );
      when(() => repository.getCurrentSession()).thenAnswer(
        (_) async =>
            Right(authenticatedSession(requiresInitialCloudMigration: true)),
      );

      final orchestrator = buildOrchestrator(hooks: <PostSyncHook>[hook]);
      final result = await orchestrator.run(SyncTrigger.initialSignIn);

      expect(result.status, SyncRunStatus.failed);
      expect(hook.invocations, isEmpty);
    });
  });

  // "hooks are not run when sync is skipped for a non-auth reason" removed:
  // no skip path is reachable now that guest sessions are gone.

  test('pulledFeatures set handed to hooks is immutable', () async {
    final hook = _RecordingHook(
      name: 'factor_heal',
      triggeringFeatures: const {'exercises'},
    );

    final orchestrator = buildOrchestrator(hooks: <PostSyncHook>[hook]);
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession()));

    await orchestrator.run(SyncTrigger.appLaunch);

    expect(hook.invocations, hasLength(1));
    expect(
      () => hook.invocations.single.pulledFeatures.add('targets'),
      throwsUnsupportedError,
    );
  });

  test('default constructor uses an empty hook list so existing orchestrator '
      'wiring remains backwards-compatible', () {
    final orchestrator = SyncOrchestratorImpl(
      appSessionRepository: repository,
      syncPolicy: AppSyncPolicy.productionDefault,
      remoteSyncAvailability: RemoteSyncAvailability(
        runtimePolicy: runtimePolicy,
        networkStatusService: networkStatusService,
      ),
      initialCloudMigrationCoordinator: migrationCoordinator,
      features: const <SyncFeature>[],
    );

    expect(orchestrator.postSyncHooks, isEmpty);
  });
}
