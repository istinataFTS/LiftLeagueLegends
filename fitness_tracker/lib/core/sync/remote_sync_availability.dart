import '../../core/enums/sync_trigger.dart';
import '../../domain/entities/app_session.dart';
import '../network/network_status_service.dart';
import 'remote_sync_runtime_policy.dart';

class RemoteSyncAvailabilityDecision {
  final bool isAllowed;
  final String reason;

  const RemoteSyncAvailabilityDecision({
    required this.isAllowed,
    required this.reason,
  });

  const RemoteSyncAvailabilityDecision.allowed()
    : isAllowed = true,
      reason = 'remote sync allowed';

  const RemoteSyncAvailabilityDecision.denied(this.reason) : isAllowed = false;
}

class RemoteSyncAvailability {
  final RemoteSyncRuntimePolicy runtimePolicy;
  final NetworkStatusService networkStatusService;

  const RemoteSyncAvailability({
    required this.runtimePolicy,
    required this.networkStatusService,
  });

  Future<RemoteSyncAvailabilityDecision> evaluate({
    required AppSession session,
    required SyncTrigger trigger,
  }) async {
    if (!runtimePolicy.isRemoteSyncConfigured) {
      return const RemoteSyncAvailabilityDecision.denied(
        'remote backend not configured',
      );
    }

    final isNetworkAvailable = await networkStatusService.isNetworkAvailable();
    if (!isNetworkAvailable) {
      return const RemoteSyncAvailabilityDecision.denied('network unavailable');
    }

    if (session.requiresInitialCloudMigration &&
        trigger != SyncTrigger.initialSignIn) {
      return const RemoteSyncAvailabilityDecision.denied(
        'initial cloud migration is pending',
      );
    }

    return const RemoteSyncAvailabilityDecision.allowed();
  }
}
