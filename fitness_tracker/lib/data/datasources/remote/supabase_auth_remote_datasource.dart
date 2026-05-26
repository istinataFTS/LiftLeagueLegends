import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/sync_exceptions.dart';
import '../../../domain/entities/app_user.dart';
import 'auth_remote_datasource.dart';
import 'remote_datasource_guard.dart';
import 'supabase_client_provider.dart';

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  final SupabaseClientProvider clientProvider;

  const SupabaseAuthRemoteDataSource({required this.clientProvider});

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<AppUser?> getCurrentUser() async {
    if (!isConfigured) {
      return null;
    }

    final user = clientProvider.client.auth.currentUser;
    if (user == null) {
      return null;
    }

    return _mapUser(user);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) {
    return RemoteDatasourceGuard.run(() async {
      final response = await clientProvider.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthSyncException('sign-in completed without a user');
      }

      return _mapUser(user);
    });
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) {
    return RemoteDatasourceGuard.run(() async {
      final response = await clientProvider.client.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{'display_name': username, 'username': username},
      );

      final user = response.user;
      if (user == null) {
        throw const AuthSyncException('sign-up completed without a user');
      }

      return SignUpResult(
        user: _mapUser(user),
        // When Supabase requires email confirmation, no session is issued.
        requiresEmailConfirmation: response.session == null,
      );
    });
  }

  @override
  Future<AppUser> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return RemoteDatasourceGuard.run(() async {
      final response = await clientProvider.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthSyncException(
          'OTP verification completed without a user',
        );
      }

      return _mapUser(user);
    });
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return RemoteDatasourceGuard.run(() async {
      await clientProvider.client.auth.resetPasswordForEmail(email);
    });
  }

  @override
  Future<void> signOut() {
    return RemoteDatasourceGuard.run(() async {
      await clientProvider.client.auth.signOut();
    });
  }

  AppUser _mapUser(dynamic user) {
    return AppUser(
      id: user.id as String,
      email: (user.email ?? '') as String,
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }
}
