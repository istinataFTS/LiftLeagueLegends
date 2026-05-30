import '../enums/conflict_resolution_strategy.dart';
import '../enums/sync_trigger.dart';
import 'app_data_architecture.dart';

class AppSyncPolicy {
  final bool offlineFirst;
  final bool localStoreAcceptsWrites;
  final bool remoteIsSourceOfTruthWhenAuthenticated;
  final ConflictResolutionStrategy conflictResolutionStrategy;
  final List<SyncTrigger> syncTriggers;

  const AppSyncPolicy({
    required this.offlineFirst,
    required this.localStoreAcceptsWrites,
    required this.remoteIsSourceOfTruthWhenAuthenticated,
    required this.conflictResolutionStrategy,
    required this.syncTriggers,
  });

  /// This is the currently accepted target architecture:
  ///
  /// - offline-first
  /// - authenticated data is user-scoped
  /// - remote becomes authoritative after login
  /// - local storage remains available for offline behavior and migration
  static const AppSyncPolicy productionDefault = AppSyncPolicy(
    offlineFirst: AppDataArchitecture.offlineFirst,
    localStoreAcceptsWrites: AppDataArchitecture.localStoreAcceptsWrites,
    remoteIsSourceOfTruthWhenAuthenticated:
        AppDataArchitecture.authenticatedRemoteIsSourceOfTruth,
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
