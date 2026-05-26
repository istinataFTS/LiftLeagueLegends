import 'package:equatable/equatable.dart';

import '../../core/enums/auth_mode.dart';
import 'app_user.dart';

class AppSession extends Equatable {
  final AuthMode authMode;
  final AppUser? user;
  final bool requiresInitialCloudMigration;
  final DateTime? lastCloudSyncAt;

  const AppSession({
    required this.authMode,
    this.user,
    this.requiresInitialCloudMigration = false,
    this.lastCloudSyncAt,
  });

  const AppSession.guest()
    : authMode = AuthMode.guest,
      user = null,
      requiresInitialCloudMigration = false,
      lastCloudSyncAt = null;

  bool get isGuest => authMode == AuthMode.guest;

  bool get isAuthenticated =>
      authMode == AuthMode.authenticated && user != null;

  AppSession copyWith({
    AuthMode? authMode,
    AppUser? user,
    bool clearUser = false,
    bool? requiresInitialCloudMigration,
    DateTime? lastCloudSyncAt,
    bool clearLastCloudSyncAt = false,
  }) {
    return AppSession(
      authMode: authMode ?? this.authMode,
      user: clearUser ? null : (user ?? this.user),
      requiresInitialCloudMigration:
          requiresInitialCloudMigration ?? this.requiresInitialCloudMigration,
      lastCloudSyncAt: clearLastCloudSyncAt
          ? null
          : (lastCloudSyncAt ?? this.lastCloudSyncAt),
    );
  }

  @override
  List<Object?> get props => [
    authMode,
    user,
    requiresInitialCloudMigration,
    lastCloudSyncAt,
  ];
}
