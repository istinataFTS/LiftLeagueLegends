import 'package:equatable/equatable.dart';

import 'app_user.dart';

class AppSession extends Equatable {
  final AppUser user;
  final bool requiresInitialCloudMigration;
  final DateTime? lastCloudSyncAt;

  const AppSession({
    required this.user,
    this.requiresInitialCloudMigration = false,
    this.lastCloudSyncAt,
  });

  AppSession copyWith({
    AppUser? user,
    bool? requiresInitialCloudMigration,
    DateTime? lastCloudSyncAt,
    bool clearLastCloudSyncAt = false,
  }) {
    return AppSession(
      user: user ?? this.user,
      requiresInitialCloudMigration:
          requiresInitialCloudMigration ?? this.requiresInitialCloudMigration,
      lastCloudSyncAt: clearLastCloudSyncAt
          ? null
          : (lastCloudSyncAt ?? this.lastCloudSyncAt),
    );
  }

  @override
  List<Object?> get props => [
    user,
    requiresInitialCloudMigration,
    lastCloudSyncAt,
  ];
}
