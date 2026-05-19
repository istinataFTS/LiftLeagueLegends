import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/core/enums/sync_trigger.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/session/session_sync_service.dart';
import 'package:fitness_tracker/core/session/session_sync_service_impl.dart';
import 'package:fitness_tracker/core/sync/sync_feature.dart';
import 'package:fitness_tracker/core/sync/sync_orchestrator.dart';
import 'package:fitness_tracker/data/datasources/local/exercise_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/meal_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/nutrition_log_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/muscle_stimulus_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/auth_remote_datasource.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockExerciseLocalDataSource extends Mock
    implements ExerciseLocalDataSource {}

class MockMealLocalDataSource extends Mock implements MealLocalDataSource {}

class MockNutritionLogLocalDataSource extends Mock
    implements NutritionLogLocalDataSource {}

class MockWorkoutSetLocalDataSource extends Mock
    implements WorkoutSetLocalDataSource {}

class MockMuscleStimulusLocalDataSource extends Mock
    implements MuscleStimulusLocalDataSource {}

class MockRebuildMuscleStimulus extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AppUser(id: '', email: ''));
    registerFallbackValue(SyncTrigger.initialSignIn);
  });

  late MockAppSessionRepository repository;
  late MockSyncOrchestrator syncOrchestrator;
  late MockAuthRemoteDataSource authRemoteDataSource;
  late MockExerciseLocalDataSource exerciseLocalDataSource;
  late MockMealLocalDataSource mealLocalDataSource;
  late MockNutritionLogLocalDataSource nutritionLogLocalDataSource;
  late MockWorkoutSetLocalDataSource workoutSetLocalDataSource;
  late MockMuscleStimulusLocalDataSource muscleStimulusLocalDataSource;
  late MockRebuildMuscleStimulus rebuildMuscleStimulus;
  late SessionSyncService service;

  const user = AppUser(
    id: 'user-1',
    email: 'user@test.com',
    displayName: 'Marin',
  );

  final AppSession authenticatedSession = AppSession(
    authMode: AuthMode.authenticated,
    user: user,
  );

  setUp(() {
    repository = MockAppSessionRepository();
    syncOrchestrator = MockSyncOrchestrator();
    authRemoteDataSource = MockAuthRemoteDataSource();
    exerciseLocalDataSource = MockExerciseLocalDataSource();
    mealLocalDataSource = MockMealLocalDataSource();
    nutritionLogLocalDataSource = MockNutritionLogLocalDataSource();
    workoutSetLocalDataSource = MockWorkoutSetLocalDataSource();
    muscleStimulusLocalDataSource = MockMuscleStimulusLocalDataSource();
    rebuildMuscleStimulus = MockRebuildMuscleStimulus();

    // Default stub: rebuild succeeds silently.
    when(
      () => rebuildMuscleStimulus(any()),
    ).thenAnswer((_) async => const Right(null));

    when(
      () => repository.syncPolicy,
    ).thenReturn(AppSyncPolicy.productionDefault);

    // signOut reads the session upfront to capture userId for targeted cleanup.
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => Right(authenticatedSession));

    // Default stubs so tests that don't exercise these paths don't crash.
    when(() => authRemoteDataSource.signOut()).thenAnswer((_) async {});
    when(
      () => repository.clearSession(),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => exerciseLocalDataSource.clearUserOwnedExercises(any()),
    ).thenAnswer((_) async {});
    when(() => mealLocalDataSource.clearAllMeals()).thenAnswer((_) async {});
    when(
      () => nutritionLogLocalDataSource.clearAllLogs(),
    ).thenAnswer((_) async {});
    when(
      () => workoutSetLocalDataSource.clearAllSets(),
    ).thenAnswer((_) async {});
    when(
      () => muscleStimulusLocalDataSource.clearStimulusForUser(any()),
    ).thenAnswer((_) async {});

    service = SessionSyncServiceImpl(
      appSessionRepository: repository,
      authRemoteDataSource: authRemoteDataSource,
      syncOrchestrator: syncOrchestrator,
      rebuildMuscleStimulus: rebuildMuscleStimulus,
      exerciseLocalDataSource: exerciseLocalDataSource,
      mealLocalDataSource: mealLocalDataSource,
      nutritionLogLocalDataSource: nutritionLogLocalDataSource,
      workoutSetLocalDataSource: workoutSetLocalDataSource,
      muscleStimulusLocalDataSource: muscleStimulusLocalDataSource,
    );
  });

  test(
    'persists session and delegates initial sign-in flow to orchestrator',
    () async {
      when(
        () => repository.startAuthenticatedSession(
          any(),
          requiresInitialCloudMigration: any(
            named: 'requiresInitialCloudMigration',
          ),
        ),
      ).thenAnswer((_) async => const Right(null));

      when(() => syncOrchestrator.run(SyncTrigger.initialSignIn)).thenAnswer(
        (_) async => const SyncRunResult(
          status: SyncRunStatus.completed,
          trigger: SyncTrigger.initialSignIn,
          message: 'initial cloud migration completed successfully',
          featureResults: <SyncFeatureRunResult>[],
        ),
      );

      final result = await service.establishAuthenticatedSession(user);

      expect(result.isSuccess, isTrue);
      expect(result.message, 'authenticated session established');

      verify(
        () => repository.startAuthenticatedSession(
          user,
          requiresInitialCloudMigration: true,
        ),
      ).called(1);
      verify(() => syncOrchestrator.run(SyncTrigger.initialSignIn)).called(1);
      verifyNever(() => repository.completeInitialCloudMigration());
    },
  );

  test('sign-in still succeeds when initial migration completed with errors '
      '(a failed step must not lock the user out)', () async {
    when(
      () => repository.startAuthenticatedSession(
        any(),
        requiresInitialCloudMigration: any(
          named: 'requiresInitialCloudMigration',
        ),
      ),
    ).thenAnswer((_) async => const Right(null));

    // The orchestrator maps a partial migration to SyncRunStatus.completed
    // (see SyncOrchestratorImpl.completedWithErrors handling), so the
    // session layer sees a non-failure and establishes the session.
    when(() => syncOrchestrator.run(SyncTrigger.initialSignIn)).thenAnswer(
      (_) async => const SyncRunResult(
        status: SyncRunStatus.completed,
        trigger: SyncTrigger.initialSignIn,
        message:
            'initial migration completed with errors; will retry: exercises',
        featureResults: <SyncFeatureRunResult>[],
      ),
    );

    final result = await service.establishAuthenticatedSession(user);

    expect(result.isSuccess, isTrue);
    // Migration left incomplete on purpose → not marked complete here.
    verifyNever(() => repository.completeInitialCloudMigration());
  });

  test('fails when authenticated session cannot be persisted', () async {
    when(
      () => repository.startAuthenticatedSession(
        any(),
        requiresInitialCloudMigration: any(
          named: 'requiresInitialCloudMigration',
        ),
      ),
    ).thenAnswer((_) async => const Left(CacheFailure('write failed')));

    final result = await service.establishAuthenticatedSession(user);

    expect(result.isFailure, isTrue);
    expect(
      result.message,
      'failed to persist authenticated session: write failed',
    );

    verifyNever(() => syncOrchestrator.run(any()));
    verifyNever(() => repository.completeInitialCloudMigration());
  });

  test('fails when initial sign-in orchestration fails', () async {
    when(
      () => repository.startAuthenticatedSession(
        any(),
        requiresInitialCloudMigration: any(
          named: 'requiresInitialCloudMigration',
        ),
      ),
    ).thenAnswer((_) async => const Right(null));

    when(() => syncOrchestrator.run(SyncTrigger.initialSignIn)).thenAnswer(
      (_) async => const SyncRunResult(
        status: SyncRunStatus.failed,
        trigger: SyncTrigger.initialSignIn,
        message: 'initial cloud migration failed',
        featureResults: <SyncFeatureRunResult>[],
      ),
    );

    final result = await service.establishAuthenticatedSession(user);

    expect(result.isFailure, isTrue);
    expect(
      result.message,
      'initial sign-in sync failed: initial cloud migration failed',
    );
  });

  test('skips when initial sign-in orchestration is skipped', () async {
    when(
      () => repository.startAuthenticatedSession(
        any(),
        requiresInitialCloudMigration: any(
          named: 'requiresInitialCloudMigration',
        ),
      ),
    ).thenAnswer((_) async => const Right(null));

    when(() => syncOrchestrator.run(SyncTrigger.initialSignIn)).thenAnswer(
      (_) async => const SyncRunResult(
        status: SyncRunStatus.skipped,
        trigger: SyncTrigger.initialSignIn,
        message: 'initial cloud migration already completed',
        featureResults: <SyncFeatureRunResult>[],
      ),
    );

    final result = await service.establishAuthenticatedSession(user);

    expect(result.isSkipped, isTrue);
    expect(
      result.message,
      'initial sign-in sync skipped: initial cloud migration already completed',
    );
  });

  test('manual refresh delegates to manual refresh sync trigger', () async {
    when(() => syncOrchestrator.run(SyncTrigger.manualRefresh)).thenAnswer(
      (_) async => const SyncRunResult(
        status: SyncRunStatus.completed,
        trigger: SyncTrigger.manualRefresh,
        message: 'refresh ok',
        featureResults: <SyncFeatureRunResult>[],
      ),
    );

    final result = await service.runManualRefresh();

    expect(result.isSuccess, isTrue);
    expect(result.message, 'manual refresh completed successfully');

    verify(() => syncOrchestrator.run(SyncTrigger.manualRefresh)).called(1);
  });

  test(
    'manual refresh returns skipped result when orchestration is skipped',
    () async {
      when(() => syncOrchestrator.run(SyncTrigger.manualRefresh)).thenAnswer(
        (_) async => const SyncRunResult(
          status: SyncRunStatus.skipped,
          trigger: SyncTrigger.manualRefresh,
          message: 'session is not authenticated',
          featureResults: <SyncFeatureRunResult>[],
        ),
      );

      final result = await service.runManualRefresh();

      expect(result.isSkipped, isTrue);
      expect(
        result.message,
        'manual refresh skipped: session is not authenticated',
      );
    },
  );

  group('signOut', () {
    test(
      'signs out remotely, clears session, and wipes all local user data',
      () async {
        final result = await service.signOut();

        expect(result.isSuccess, isTrue);
        expect(result.message, 'sign-out completed successfully');

        verify(() => authRemoteDataSource.signOut()).called(1);
        verify(() => repository.clearSession()).called(1);
        // All user-scoped tables must be cleared.
        verify(() => mealLocalDataSource.clearAllMeals()).called(1);
        verify(() => nutritionLogLocalDataSource.clearAllLogs()).called(1);
        verify(() => workoutSetLocalDataSource.clearAllSets()).called(1);
        // Only user-owned exercises — seeded rows are preserved.
        verify(
          () => exerciseLocalDataSource.clearUserOwnedExercises('user-1'),
        ).called(1);
        // Muscle stimulus cleared for this user only.
        verify(
          () => muscleStimulusLocalDataSource.clearStimulusForUser('user-1'),
        ).called(1);
      },
    );

    test(
      'fails when remote sign-out throws; no local state is touched',
      () async {
        when(
          () => authRemoteDataSource.signOut(),
        ).thenThrow('remote sign-out failed');

        final result = await service.signOut();

        expect(result.isFailure, isTrue);
        expect(result.message, 'sign-out failed: remote sign-out failed');

        verifyNever(() => repository.clearSession());
        verifyNever(() => mealLocalDataSource.clearAllMeals());
        verifyNever(() => nutritionLogLocalDataSource.clearAllLogs());
        verifyNever(() => workoutSetLocalDataSource.clearAllSets());
        verifyNever(
          () => exerciseLocalDataSource.clearUserOwnedExercises(any()),
        );
        verifyNever(
          () => muscleStimulusLocalDataSource.clearStimulusForUser(any()),
        );
      },
    );

    test('fails when local session clear fails but still performs best-effort '
        'data cleanup', () async {
      when(() => repository.clearSession()).thenAnswer(
        (_) async => const Left(CacheFailure('session reset failed')),
      );

      final result = await service.signOut();

      expect(result.isFailure, isTrue);
      expect(
        result.message,
        'sign-out succeeded remotely but local session reset failed: session reset failed',
      );

      // Best-effort cleanup must still run even when the session clear fails.
      // The AuthSessionShell key change is the primary data-isolation guard,
      // but a clean database matters for reinstall / edge-case scenarios.
      verify(() => mealLocalDataSource.clearAllMeals()).called(1);
      verify(() => nutritionLogLocalDataSource.clearAllLogs()).called(1);
      verify(() => workoutSetLocalDataSource.clearAllSets()).called(1);
      verify(
        () => exerciseLocalDataSource.clearUserOwnedExercises('user-1'),
      ).called(1);
      verify(
        () => muscleStimulusLocalDataSource.clearStimulusForUser('user-1'),
      ).called(1);
    });

    test('skips clearUserOwnedExercises when no authenticated user', () async {
      when(
        () => repository.getCurrentSession(),
      ).thenAnswer((_) async => const Right(AppSession.guest()));

      final result = await service.signOut();

      expect(result.isSuccess, isTrue);
      // Exercises: nothing to delete — no userId.
      verifyNever(() => exerciseLocalDataSource.clearUserOwnedExercises(any()));
      // Muscle stimulus: nothing to delete — no userId.
      verifyNever(
        () => muscleStimulusLocalDataSource.clearStimulusForUser(any()),
      );
      // Other tables are always cleared.
      verify(() => mealLocalDataSource.clearAllMeals()).called(1);
    });
  });
}
