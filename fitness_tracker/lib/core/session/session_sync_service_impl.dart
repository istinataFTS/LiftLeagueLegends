import '../../core/logging/app_logger.dart';
import '../../data/datasources/local/exercise_local_datasource.dart';
import '../../data/datasources/local/meal_local_datasource.dart';
import '../../data/datasources/local/muscle_stimulus_local_datasource.dart';
import '../../data/datasources/local/nutrition_log_local_datasource.dart';
import '../../data/datasources/local/workout_set_local_datasource.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../enums/sync_trigger.dart';
import '../sync/sync_orchestrator.dart';
import 'session_sync_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/app_session_repository.dart';
import '../../domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';

class SessionSyncServiceImpl implements SessionSyncService {
  final AppSessionRepository appSessionRepository;
  final AuthRemoteDataSource authRemoteDataSource;
  final SyncOrchestrator syncOrchestrator;
  final RebuildMuscleStimulusFromWorkoutHistory rebuildMuscleStimulus;
  final ExerciseLocalDataSource exerciseLocalDataSource;
  final MealLocalDataSource mealLocalDataSource;
  final MuscleStimulusLocalDataSource muscleStimulusLocalDataSource;
  final NutritionLogLocalDataSource nutritionLogLocalDataSource;
  final WorkoutSetLocalDataSource workoutSetLocalDataSource;

  const SessionSyncServiceImpl({
    required this.appSessionRepository,
    required this.authRemoteDataSource,
    required this.syncOrchestrator,
    required this.rebuildMuscleStimulus,
    required this.exerciseLocalDataSource,
    required this.mealLocalDataSource,
    required this.muscleStimulusLocalDataSource,
    required this.nutritionLogLocalDataSource,
    required this.workoutSetLocalDataSource,
  });

  @override
  Future<SessionSyncActionResult> establishAuthenticatedSession(
    AppUser user,
  ) async {
    final startSessionResult = await appSessionRepository
        .startAuthenticatedSession(user);

    return await startSessionResult.fold(
      (failure) async {
        AppLogger.error(
          'Failed to persist authenticated session',
          category: 'session',
          error: failure,
        );

        return SessionSyncActionResult(
          status: SessionSyncActionStatus.failed,
          message:
              'failed to persist authenticated session: ${failure.message}',
        );
      },
      (_) async {
        AppLogger.info(
          'Authenticated session persisted; starting authenticated session synchronization',
          category: 'session',
        );

        final syncResult = await syncOrchestrator.run(
          SyncTrigger.initialSignIn,
        );

        if (syncResult.isFailure) {
          return SessionSyncActionResult(
            status: SessionSyncActionStatus.failed,
            message: 'initial sign-in sync failed: ${syncResult.message}',
            syncResult: syncResult,
          );
        }

        if (syncResult.isSkipped) {
          return SessionSyncActionResult(
            status: SessionSyncActionStatus.skipped,
            message: 'initial sign-in sync skipped: ${syncResult.message}',
            syncResult: syncResult,
          );
        }

        // After a successful pull, the workout_sets table is repopulated from
        // Supabase.  Rebuild the muscle_stimulus projection so the body map
        // and fatigue views immediately reflect the restored training history.
        // muscle_stimulus is derived data — it is never synced remotely.
        await _rebuildMuscleStimulus(user.id);

        return SessionSyncActionResult(
          status: SessionSyncActionStatus.completed,
          message: 'authenticated session established',
          syncResult: syncResult,
        );
      },
    );
  }

  @override
  Future<SessionSyncActionResult> runManualRefresh() async {
    final syncResult = await syncOrchestrator.run(SyncTrigger.manualRefresh);

    switch (syncResult.status) {
      case SyncRunStatus.completed:
        return SessionSyncActionResult(
          status: SessionSyncActionStatus.completed,
          message: 'manual refresh completed successfully',
          syncResult: syncResult,
        );
      case SyncRunStatus.skipped:
        return SessionSyncActionResult(
          status: SessionSyncActionStatus.skipped,
          message: 'manual refresh skipped: ${syncResult.message}',
          syncResult: syncResult,
        );
      case SyncRunStatus.failed:
        return SessionSyncActionResult(
          status: SessionSyncActionStatus.failed,
          message: 'manual refresh failed: ${syncResult.message}',
          syncResult: syncResult,
        );
    }
  }

  @override
  Future<SessionSyncActionResult> signOut() async {
    // Capture the user id now, before the session is cleared.  We need it
    // to perform a targeted exercise delete (only user-owned rows, not seeds).
    final sessionResult = await appSessionRepository.getCurrentSession();
    final userId = sessionResult.fold((_) => null, (s) => s.user?.id);

    try {
      await authRemoteDataSource.signOut();
    } catch (error) {
      AppLogger.warning('Remote sign-out failed: $error', category: 'session');

      return SessionSyncActionResult(
        status: SessionSyncActionStatus.failed,
        message: 'sign-out failed: $error',
      );
    }

    final clearSessionResult = await appSessionRepository.clearSession();

    return await clearSessionResult.fold(
      (failure) async {
        AppLogger.error(
          'Remote sign-out succeeded but local session clear failed',
          category: 'session',
          error: failure,
        );

        // Best-effort data cleanup even when the session clear failed.
        // The AuthSessionShell key change is the primary safeguard, but a
        // clean database is still important for fresh installs or edge cases.
        await _clearAllLocalUserData(userId);

        return SessionSyncActionResult(
          status: SessionSyncActionStatus.failed,
          message:
              'sign-out succeeded remotely but local session reset failed: ${failure.message}',
        );
      },
      (_) async {
        await _clearAllLocalUserData(userId);

        AppLogger.info(
          'Session signed out, local session reset, and local user data cleared',
          category: 'session',
        );

        return const SessionSyncActionResult(
          status: SessionSyncActionStatus.completed,
          message: 'sign-out completed successfully',
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Rebuilds [muscle_stimulus] rows from [workout_sets] for [userId].
  ///
  /// Called after the initial sign-in pull so that the body map and fatigue
  /// views immediately reflect training history restored from Supabase.
  /// Failures are non-fatal — the user can still use the app; the map will
  /// self-heal on the next workout log.
  Future<void> _rebuildMuscleStimulus(String userId) async {
    AppLogger.info(
      'Rebuilding muscle stimulus from restored workout history...',
      category: 'session',
    );

    final rebuildStart = DateTime.now();
    final result = await rebuildMuscleStimulus(userId);
    final elapsed = DateTime.now().difference(rebuildStart);

    result.fold(
      (failure) {
        AppLogger.warning(
          'Muscle stimulus rebuild failed after sign-in: ${failure.message}',
          category: 'session',
        );
      },
      (_) {
        AppLogger.info(
          'Muscle stimulus rebuilt in ${elapsed.inMilliseconds}ms',
          category: 'session',
        );
      },
    );
  }

  /// Clears all local data belonging to the signing-out user.
  ///
  /// Ordering matters for FK integrity:
  /// - meals before nutrition_logs (nutrition_logs.meal_id → meals.id)
  /// - workout_sets and muscle_stimulus are independent of the above
  /// - exercises: only the signing-out user's own rows (owner_user_id =
  ///   userId); the guest '' catalog and other accounts' rows are preserved
  ///   (per-user catalog model, db v20+)
  Future<void> _clearAllLocalUserData(String? userId) async {
    try {
      // meals first — nutrition_logs reference meal_id via FK
      await mealLocalDataSource.clearAllMeals();
      await nutritionLogLocalDataSource.clearAllLogs();

      await workoutSetLocalDataSource.clearAllSets();

      // User-scoped tables: only clear when a real authenticated userId is
      // present.  Guest sessions have no owned rows to remove.
      if (userId != null) {
        await Future.wait(<Future<void>>[
          // exercises: targeted delete (owner_user_id = userId) so the
          // guest '' catalog and any other account's rows are preserved.
          exerciseLocalDataSource.clearUserOwnedExercises(userId),
          // Scope muscle_stimulus removal to the signing-out user only so
          // other profiles' training history is not affected.
          muscleStimulusLocalDataSource.clearStimulusForUser(userId),
        ]);
      }
    } catch (error) {
      AppLogger.warning(
        'Failed to fully clear local user data on sign-out: $error',
        category: 'session',
      );
    }
  }
}
