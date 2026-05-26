import '../../../domain/entities/app_user.dart';

class SignUpResult {
  final AppUser user;
  final bool requiresEmailConfirmation;

  const SignUpResult({
    required this.user,
    required this.requiresEmailConfirmation,
  });
}

abstract class AuthRemoteDataSource {
  bool get isConfigured;

  Future<AppUser?> getCurrentUser();
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  });

  Future<AppUser> verifyEmailOtp({
    required String email,
    required String token,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
