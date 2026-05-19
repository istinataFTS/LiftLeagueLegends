import 'dart:async';

import '../../data/sync/entity_sync_batch_failure.dart';
import '../../domain/entities/app_session.dart';
import '../../domain/repositories/app_session_repository.dart';
import '../config/app_sync_policy.dart';
import '../enums/sync_trigger.dart';
import '../errors/sync_exceptions.dart';
import '../logging/app_logger.dart';
import 'initial_cloud_migration_coordinator.dart';
import 'post_sync_hook.dart';
import 'remote_sync_availability.dart';
import 'sync_feature.dart';
import 'sync_orchestrator.dart';

class SyncOrchestratorImpl implements SyncOrchestrator {
  final AppSessionRepository appSessionRepository;
  final AppSyncPolicy syncPolicy;
  final RemoteSyncAvailability remoteSyncAvailability;
  final InitialCloudMigrationCoordinator initialCloudMigrationCoordinator;
  final List<SyncFeature> features;
  final List<PostSyncHook> postSyncHooks;

  bool _isSyncing = false;

  /// Broadcast so the stream can outlive individual listeners: the
  /// orchestrator is an app-lifetime singleton while UI listeners are
  /// recreated on every session switch.
  final StreamController<SyncRunResult> _syncCompletedController =
      StreamController<SyncRunResult>.broadcast();

  @override
  Stream<SyncRunResult> get onSyncCompleted => _syncCompletedController.stream;

  SyncOrchestratorImpl({
    required this.appSessionRepository,
    required this.syncPolicy,
    required this.remoteSyncAvailability,
    required this.initialCloudMigrationCoordinator,
    required this.features,
    this.postSyncHooks = const <PostSyncHook>[],
  });

  @override
  Future<SyncRunResult> run(SyncTrigger trigger) async {
    final SyncRunResult result = await _run(trigger);

    if (result.status == SyncRunStatus.completed ||
        result.status == SyncRunStatus.failed) {
      _syncCompletedController.add(result);
    }

    return result;
  }

  Future<SyncRunResult> _run(SyncTrigger trigger) async {
    if (_isSyncing) {
      AppLogger.info(
        'Sync orchestration skipped for $trigger: sync already in progress',
        category: 'sync',
      );

      return SyncRunResult(
        status: SyncRunStatus.skipped,
        trigger: trigger,
        message: 'sync already in progress',
      );
    }

    if (!syncPolicy.syncTriggers.contains(trigger)) {
      return SyncRunResult(
        status: SyncRunStatus.skipped,
        trigger: trigger,
        message: 'trigger is disabled by sync policy',
      );
    }

    _isSyncing = true;

    try {
      final sessionResult = await appSessionRepository.getCurrentSession();

      return await sessionResult.fold(
        (failure) async {
          AppLogger.warning(
            'Sync orchestration skipped because session lookup failed: ${failure.message}',
            category: 'sync',
          );

          return SyncRunResult(
            status: SyncRunStatus.failed,
            trigger: trigger,
            message: 'session lookup failed: ${failure.message}',
          );
        },
        (session) async {
          final availability = await remoteSyncAvailability.evaluate(
            session: session,
            trigger: trigger,
          );

          if (!availability.isAllowed) {
            AppLogger.info(
              'Sync orchestration skipped for $trigger: ${availability.reason}',
              category: 'sync',
            );

            return SyncRunResult(
              status: SyncRunStatus.skipped,
              trigger: trigger,
              message: availability.reason,
            );
          }

          if (session.requiresInitialCloudMigration) {
            return _runInitialMigration(trigger, session);
          }

          return _runFeatureSync(trigger, session);
        },
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<SyncRunResult> _runInitialMigration(
    SyncTrigger trigger,
    AppSession session,
  ) async {
    AppLogger.info(
      'Initial cloud migration orchestration started for $trigger',
      category: 'sync',
    );

    final migrationResult = await initialCloudMigrationCoordinator
        .runIfRequired();

    switch (migrationResult.status) {
      case InitialCloudMigrationStatus.completed:
        await _recordSuccessfulCloudSync();

        // Every migration step pulls remote rows for its feature, so a
        // completed migration is equivalent to a full pull across all
        // registered sync features. Post-sync hooks that depend on
        // exercises / workout_sets being fresh (factor heal, stimulus
        // rebuild) need this signal.
        final pulledFeatures = features.map((f) => f.name).toSet();
        await _runPostSyncHooks(
          trigger: trigger,
          session: session,
          pulledFeatures: pulledFeatures,
        );

        return SyncRunResult(
          status: SyncRunStatus.completed,
          trigger: trigger,
          message: 'initial cloud migration completed successfully',
        );

      case InitialCloudMigrationStatus.completedWithErrors:
        // The session must still be established (the user is not locked out
        // of their own account). Run only the always-on local hooks (empty
        // pulledFeatures): a step failed, so feature-gated hooks must not
        // assume their feature pulled cleanly. Deliberately do NOT record a
        // successful cloud sync — the migration is incomplete and must
        // re-run its failed steps on the next sync.
        await _runPostSyncHooks(
          trigger: trigger,
          session: session,
          pulledFeatures: const <String>{},
        );

        return SyncRunResult(
          status: SyncRunStatus.completed,
          trigger: trigger,
          message: migrationResult.message,
        );

      case InitialCloudMigrationStatus.skipped:
        return SyncRunResult(
          status: SyncRunStatus.skipped,
          trigger: trigger,
          message: migrationResult.message,
        );

      case InitialCloudMigrationStatus.inProgress:
        return SyncRunResult(
          status: SyncRunStatus.skipped,
          trigger: trigger,
          message: migrationResult.message,
        );

      case InitialCloudMigrationStatus.failed:
        return SyncRunResult(
          status: SyncRunStatus.failed,
          trigger: trigger,
          message: migrationResult.message,
        );
    }
  }

  /// Runs all registered features in FK order.
  ///
  /// Each feature **pulls first, then pushes**:
  /// 1. Pull — download remote rows modified since [session.lastCloudSyncAt]
  ///    (null on first login → full pull).  This repopulates local storage
  ///    after a logout/re-login and keeps multi-device data in sync.
  /// 2. Push — upload locally pending changes that accumulated while offline.
  ///
  /// Ordering is FK-safe: exercises → meals → workout_sets → nutrition_logs →
  /// targets.
  Future<SyncRunResult> _runFeatureSync(
    SyncTrigger trigger,
    AppSession session,
  ) async {
    AppLogger.info('Sync orchestration started for $trigger', category: 'sync');

    final userId = session.user?.id ?? '';
    final since = session.lastCloudSyncAt;

    final List<SyncFeatureRunResult> featureResults = <SyncFeatureRunResult>[];
    final Set<String> pulledFeatures = <String>{};

    for (final feature in features) {
      try {
        // Pull before push: remote changes arrive first so that a subsequent
        // push does not duplicate entities that were already on the server.
        await feature.pullRemoteChanges(userId, since);
        pulledFeatures.add(feature.name);

        await feature.syncPendingChanges();

        featureResults.add(SyncFeatureRunResult.success(feature.name));

        AppLogger.info(
          'Feature sync completed: ${feature.name}',
          category: 'sync',
        );
      } catch (error, stackTrace) {
        final errorMessage = _resolveFeatureErrorMessage(error);

        featureResults.add(
          SyncFeatureRunResult.failure(
            featureName: feature.name,
            errorMessage: errorMessage,
          ),
        );

        AppLogger.error(
          'Feature sync failed: ${feature.name}',
          category: 'sync',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final bool hasFailures = featureResults.any((result) => !result.isSuccess);

    // Post-sync hooks run regardless of feature-push failures. The always-run
    // hooks (factor heal, stimulus rebuild) operate purely on local data
    // scoped to the user and are idempotent, so a failed remote push (e.g. a
    // workout_sets upsert rejected by the server) must not leave the local
    // muscle-stimulus projection stale. Hooks gated on a specific feature
    // still only fire when that feature actually pulled successfully, since
    // `pulledFeatures` only contains features whose pull completed.
    await _runPostSyncHooks(
      trigger: trigger,
      session: session,
      pulledFeatures: pulledFeatures,
    );

    if (hasFailures) {
      // Deliberately do NOT advance lastCloudSyncAt: the next sync must
      // re-attempt the failed features with the same `since` watermark.
      return SyncRunResult(
        status: SyncRunStatus.failed,
        trigger: trigger,
        message: 'one or more feature sync operations failed',
        featureResults: featureResults,
      );
    }

    await _recordSuccessfulCloudSync();

    return SyncRunResult(
      status: SyncRunStatus.completed,
      trigger: trigger,
      message: 'sync orchestration completed successfully',
      featureResults: featureResults,
    );
  }

  /// Runs every registered [PostSyncHook] whose [PostSyncHook.triggeringFeatures]
  /// intersect with [pulledFeatures], or that declare no triggering features
  /// (always-run hooks).
  ///
  /// Hook failures are logged and swallowed so one misbehaving hook cannot
  /// mark an otherwise-successful sync as failed. Hooks are invoked in
  /// registration order, sequentially, because they may depend on each other
  /// (e.g. the stimulus-rebuild hook assumes factors have been healed).
  Future<void> _runPostSyncHooks({
    required SyncTrigger trigger,
    required AppSession session,
    required Set<String> pulledFeatures,
  }) async {
    if (postSyncHooks.isEmpty) {
      return;
    }

    final userId = session.user?.id;
    if (userId == null || userId.isEmpty) {
      // Hooks need a concrete user scope to operate on. A guest or
      // unresolved session must never reach this code path, but guard
      // defensively in case the session contract changes.
      return;
    }

    final context = PostSyncContext(
      userId: userId,
      pulledFeatures: Set.unmodifiable(pulledFeatures),
      trigger: trigger,
    );

    for (final hook in postSyncHooks) {
      if (hook.triggeringFeatures.isNotEmpty &&
          hook.triggeringFeatures.intersection(pulledFeatures).isEmpty) {
        continue;
      }

      try {
        await hook.run(context);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Post-sync hook "${hook.name}" threw; swallowing so sync remains successful',
          category: 'sync',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  String _resolveFeatureErrorMessage(Object error) {
    if (error is EntitySyncBatchFailure) {
      return error.message;
    }

    if (error is NetworkSyncException) {
      return 'network error: ${error.message}';
    }

    if (error is AuthSyncException) {
      return 'auth error: ${error.message}';
    }

    if (error is RemoteSyncException) {
      return 'remote error: ${error.message}';
    }

    return error.toString();
  }

  Future<void> _recordSuccessfulCloudSync() async {
    final recordSyncResult = await appSessionRepository
        .recordSuccessfulCloudSync(DateTime.now());

    recordSyncResult.fold(
      (failure) {
        AppLogger.warning(
          'Sync completed but lastCloudSyncAt could not be persisted: ${failure.message}',
          category: 'sync',
        );
      },
      (_) {
        AppLogger.info(
          'Recorded successful cloud sync timestamp',
          category: 'sync',
        );
      },
    );
  }
}
