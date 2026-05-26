import '../../domain/entities/app_user.dart';
import '../session/session_sync_service.dart';

enum AuthSessionActionStatus { completed, failed }

class AuthSessionActionResult {
  final AuthSessionActionStatus status;
  final String message;
  final AppUser? user;
  final SessionSyncActionResult? sessionResult;

  final bool requiresEmailConfirmation;

  const AuthSessionActionResult({
    required this.status,
    required this.message,
    this.user,
    this.sessionResult,
    this.requiresEmailConfirmation = false,
  });

  bool get isSuccess => status == AuthSessionActionStatus.completed;
  bool get isFailure => status == AuthSessionActionStatus.failed;
}

abstract class AuthSessionService {
  /// Authenticates an existing user and establishes the local session.
  Future<AuthSessionActionResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Registers a new user and, when email confirmation is not required,
  /// establishes the local session immediately.
  Future<AuthSessionActionResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  });

  /// Verifies the 6-digit OTP sent to [email] during sign-up and establishes
  /// the local session on success.
  Future<AuthSessionActionResult> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<SessionSyncActionResult> signOut();
}
