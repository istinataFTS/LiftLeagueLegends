import 'dart:async';

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
  /// Emits once each time a new authenticated session is **fully** established
  /// (sign-in / sign-up / OTP) — i.e. persisted *and* its initial cloud-migration
  /// sync completed. [ProfileCubit] listens so the auth gate swaps from the
  /// sign-in screen to the app without a manual restart.
  ///
  /// A `void` announcement: listeners re-read the authoritative session via
  /// [AppSessionRepository.getCurrentSession]. This mirrors the reactive pattern
  /// already used by [AppSettingsRepository.watchSettings] / [AppSettingsCubit],
  /// applied at the session-lifecycle layer. It does **not** fire on a skipped
  /// or failed establish (those surface as sign-in errors), nor on sign-out
  /// (handled directly by [ProfileCubit.signOut]).
  Stream<void> get onSessionEstablished;

  Future<SessionSyncActionResult> establishAuthenticatedSession(AppUser user);

  Future<SessionSyncActionResult> runManualRefresh();

  Future<SessionSyncActionResult> signOut();
}
