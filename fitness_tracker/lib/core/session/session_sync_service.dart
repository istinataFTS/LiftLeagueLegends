import '../sync/sync_orchestrator.dart';
import '../../domain/entities/app_user.dart';

enum SessionSyncActionStatus { completed, skipped, failed }

class SessionSyncActionResult {
  final SessionSyncActionStatus status;
  final String message;
  final SyncRunResult? syncResult;

  const SessionSyncActionResult({
    required this.status,
    required this.message,
    this.syncResult,
  });

  bool get isSuccess => status == SessionSyncActionStatus.completed;
  bool get isSkipped => status == SessionSyncActionStatus.skipped;
  bool get isFailure => status == SessionSyncActionStatus.failed;
}

abstract class SessionSyncService {
  Future<SessionSyncActionResult> establishAuthenticatedSession(AppUser user);

  Future<SessionSyncActionResult> runManualRefresh();

  Future<SessionSyncActionResult> signOut();
}
