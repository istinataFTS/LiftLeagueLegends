import '../enums/auth_mode.dart';
import '../enums/conflict_resolution_strategy.dart';
import '../enums/sync_trigger.dart';
import 'app_data_architecture.dart';

class AppSyncPolicy {
  final bool offlineFirst;
  final bool localStoreAcceptsWrites;
  final bool remoteIsSourceOfTruthWhenAuthenticated;
  final bool guestModeUsesLocalStorageOnly;
  final bool authenticatedModeUsesUserScopedData;
  final ConflictResolutionStrategy conflictResolutionStrategy;
  final List<SyncTrigger> syncTriggers;

  const AppSyncPolicy({
    required this.offlineFirst,
    required this.localStoreAcceptsWrites,
    required this.remoteIsSourceOfTruthWhenAuthenticated,
    required this.guestModeUsesLocalStorageOnly,
    required this.authenticatedModeUsesUserScopedData,
    required this.conflictResolutionStrategy,
    required this.syncTriggers,
  });

  bool usesRemoteDataFor(AuthMode authMode) {
    if (authMode == AuthMode.guest) {
      return false;
    }

    return true;
  }

  /// This is the currently accepted target architecture for authenticated mode:
  ///
  /// - offline-first
  /// - guest mode remains local-only
  /// - authenticated data is user-scoped
  /// - remote becomes authoritative after login
  /// - local storage remains available for offline behavior and migration
  static const AppSyncPolicy productionDefault = AppSyncPolicy(
    offlineFirst: AppDataArchitecture.offlineFirst,
    localStoreAcceptsWrites: AppDataArchitecture.localStoreAcceptsWrites,
    remoteIsSourceOfTruthWhenAuthenticated:
        AppDataArchitecture.authenticatedRemoteIsSourceOfTruth,
    guestModeUsesLocalStorageOnly:
        AppDataArchitecture.guestModeUsesLocalStorageOnly,
    authenticatedModeUsesUserScopedData:
        AppDataArchitecture.authenticatedModeUsesUserScopedData,
    conflictResolutionStrategy: ConflictResolutionStrategy.serverWins,
    syncTriggers: <SyncTrigger>[
      SyncTrigger.appLaunch,
      SyncTrigger.appResume,
      SyncTrigger.manualRefresh,
      SyncTrigger.writeThrough,
      SyncTrigger.initialSignIn,
    ],
  );
}