import '../../core/logging/app_logger.dart';
import '../../domain/entities/initial_cloud_migration_state.dart';
import '../../domain/repositories/app_session_repository.dart';
import 'initial_cloud_migration_coordinator.dart';
import 'initial_cloud_migration_step.dart';

class InitialCloudMigrationCoordinatorImpl
    implements InitialCloudMigrationCoordinator {
  final AppSessionRepository appSessionRepository;
  final List<InitialCloudMigrationStep> steps;

  const InitialCloudMigrationCoordinatorImpl({
    required this.appSessionRepository,
    required this.steps,
  });

  @override
  Future<InitialCloudMigrationResult> runIfRequired() async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    return await sessionResult.fold(
      (failure) async {
        return InitialCloudMigrationResult(
          status: InitialCloudMigrationStatus.failed,
          message: 'session lookup failed: ${failure.message}',
        );
      },
      (session) async {
        if (!session.requiresInitialCloudMigration) {
          return const InitialCloudMigrationResult(
            status: InitialCloudMigrationStatus.skipped,
            message: 'initial cloud migration already completed',
          );
        }

        final user = session.user;
        final existingStateResult = await appSessionRepository
            .getInitialCloudMigrationState();

        return await existingStateResult.fold(
          (failure) async {
            return InitialCloudMigrationResult(
              status: InitialCloudMigrationStatus.failed,
              message:
                  'initial migration state lookup failed: ${failure.message}',
            );
          },
          (existingState) async {
            InitialCloudMigrationState state = _resolveStateForUser(
              existingState,
              user.id,
            );

            final initialSave = await appSessionRepository
                .saveInitialCloudMigrationState(state);

            final initialSaveFailure = initialSave.fold(
              (failure) => failure,
              (_) => null,
            );

            if (initialSaveFailure != null) {
              return InitialCloudMigrationResult(
                status: InitialCloudMigrationStatus.failed,
                message:
                    'failed to persist initial migration state: ${initialSaveFailure.message}',
                state: state,
              );
            }

            final List<String> failedSteps = <String>[];

            for (final step in steps) {
              if (_isStepCompleted(step.key, state)) {
                continue;
              }

              try {
                AppLogger.info(
                  'Running initial cloud migration step ${step.key} for user ${user.id}',
                  category: 'sync',
                );

                await step.run(user.id);

                state = _markStepCompleted(state, step.key);

                final saveResult = await appSessionRepository
                    .saveInitialCloudMigrationState(state);

                final saveFailure = saveResult.fold(
                  (failure) => failure,
                  (_) => null,
                );

                if (saveFailure != null) {
                  return InitialCloudMigrationResult(
                    status: InitialCloudMigrationStatus.failed,
                    message:
                        'failed to persist migration progress for ${step.key}: ${saveFailure.message}',
                    state: state,
                  );
                }
              } catch (error) {
                // Non-fatal: record the error, leave this step incomplete so
                // it retries on the next sync, and continue with the
                // remaining steps. The user must always be able to sign in;
                // sync converges later.
                state = state.copyWith(
                  updatedAt: DateTime.now(),
                  lastError: 'step ${step.key} failed: $error',
                );

                await appSessionRepository.saveInitialCloudMigrationState(
                  state,
                );

                AppLogger.error(
                  'Initial cloud migration step failed (continuing): '
                  '${step.key}',
                  category: 'sync',
                  error: error,
                );

                failedSteps.add(step.key);
              }
            }

            if (failedSteps.isNotEmpty) {
              // Intentionally do NOT completeInitialCloudMigration: leaving
              // the session flagged as still-requiring migration is what
              // makes the next sync re-run only the failed steps.
              return InitialCloudMigrationResult(
                status: InitialCloudMigrationStatus.completedWithErrors,
                message:
                    'initial migration completed with errors; will retry: '
                    '${failedSteps.join(', ')}',
                state: state,
              );
            }

            final completeResult = await appSessionRepository
                .completeInitialCloudMigration();

            final completeFailure = completeResult.fold(
              (failure) => failure,
              (_) => null,
            );

            if (completeFailure != null) {
              return InitialCloudMigrationResult(
                status: InitialCloudMigrationStatus.failed,
                message:
                    'migration completed but session completion flag failed: ${completeFailure.message}',
                state: state,
              );
            }

            return InitialCloudMigrationResult(
              status: InitialCloudMigrationStatus.completed,
              message: 'initial cloud migration completed successfully',
              state: state.copyWith(
                updatedAt: DateTime.now(),
                clearLastError: true,
              ),
            );
          },
        );
      },
    );
  }

  InitialCloudMigrationState _resolveStateForUser(
    InitialCloudMigrationState? existingState,
    String userId,
  ) {
    if (existingState == null) {
      return InitialCloudMigrationState.started(userId);
    }

    if (existingState.userId != userId) {
      return InitialCloudMigrationState.started(userId);
    }

    return existingState.copyWith(
      updatedAt: DateTime.now(),
      clearLastError: true,
    );
  }

  bool _isStepCompleted(String key, InitialCloudMigrationState state) {
    switch (key) {
      case 'workout_sets':
        return state.workoutSetsCompleted;
      case 'exercises':
        return state.exercisesCompleted;
      case 'meals':
        return state.mealsCompleted;
      case 'nutrition_logs':
        return state.nutritionLogsCompleted;
      case 'targets':
        return state.targetsCompleted;
      default:
        return false;
    }
  }

  InitialCloudMigrationState _markStepCompleted(
    InitialCloudMigrationState state,
    String key,
  ) {
    switch (key) {
      case 'workout_sets':
        return state.copyWith(
          workoutSetsCompleted: true,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
      case 'exercises':
        return state.copyWith(
          exercisesCompleted: true,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
      case 'meals':
        return state.copyWith(
          mealsCompleted: true,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
      case 'nutrition_logs':
        return state.copyWith(
          nutritionLogsCompleted: true,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
      case 'targets':
        return state.copyWith(
          targetsCompleted: true,
          updatedAt: DateTime.now(),
          clearLastError: true,
        );
      default:
        return state.copyWith(updatedAt: DateTime.now(), clearLastError: true);
    }
  }
}
