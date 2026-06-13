enum BackendTarget { supabasePrimary }

enum LocalStorageRole { authenticatedOfflineStore, transitionalMigrationLayer }

enum SourceOfTruth { localOnly, supabase, derivedFromUserScopedData }

class FeatureOwnershipDecision {
  final String featureKey;
  final bool userScoped;
  final SourceOfTruth sourceOfTruth;
  final bool derived;

  const FeatureOwnershipDecision({
    required this.featureKey,
    required this.userScoped,
    required this.sourceOfTruth,
    this.derived = false,
  });
}

class AppDataArchitecture {
  const AppDataArchitecture._();

  /// Milestone 2 decision:
  /// the application is being built toward Supabase as the primary backend.
  static const BackendTarget backendTarget = BackendTarget.supabasePrimary;

  /// Signed-in users operate on user-scoped data. Guest mode was removed in
  /// the `fix/remove-guest-and-unstick-migration` initiative — there is no
  /// "guest" alternative path at runtime.
  static const bool authenticatedModeUsesUserScopedData = true;

  /// Once authenticated, remote data becomes authoritative.
  static const bool authenticatedRemoteIsSourceOfTruth = true;

  /// Local storage still matters, but not as the final authority for
  /// authenticated users.
  static const List<LocalStorageRole> localStorageRoles = <LocalStorageRole>[
    LocalStorageRole.authenticatedOfflineStore,
    LocalStorageRole.transitionalMigrationLayer,
  ];

  /// The target experience remains offline-first.
  static const bool offlineFirst = true;

  /// Local writes are still allowed so repositories can support responsive UI,
  /// offline capture, and later sync.
  static const bool localStoreAcceptsWrites = true;

  /// Feature ownership decisions that later repository and schema work should
  /// follow.
  static const List<FeatureOwnershipDecision> featureOwnership =
      <FeatureOwnershipDecision>[
        FeatureOwnershipDecision(
          featureKey: 'workouts',
          userScoped: true,
          sourceOfTruth: SourceOfTruth.supabase,
        ),
        FeatureOwnershipDecision(
          featureKey: 'nutrition_logs',
          userScoped: true,
          sourceOfTruth: SourceOfTruth.supabase,
        ),
        FeatureOwnershipDecision(
          featureKey: 'meals',
          userScoped: true,
          sourceOfTruth: SourceOfTruth.supabase,
        ),
        FeatureOwnershipDecision(
          featureKey: 'history',
          userScoped: true,
          sourceOfTruth: SourceOfTruth.derivedFromUserScopedData,
          derived: true,
        ),
      ];

  /// Presentation code should stay backend-agnostic.
  static const bool keepBackendApisOutOfPresentation = true;

  /// Repositories remain the app-facing contract above local/remote details.
  static const bool repositoriesAreTheAppFacingPersistenceBoundary = true;
}
