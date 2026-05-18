/// Per-account flag that records whether a catalog type has been provisioned
/// at least once for a given owner.
///
/// Used by [SeedExercises] and [SeedMeals] to honour the delete-stickiness
/// invariant: once a user has received their default catalog (flag set), the
/// seed path skips — even if the catalog is now empty because they deleted
/// every row.  The catalog is only re-seeded when [forceReseed] is explicitly
/// enabled (developer override).
abstract class CatalogInitFlagRepository {
  /// Returns true if the catalog [catalogType] has been successfully
  /// provisioned for [ownerUserId] at least once.
  Future<bool> isInitialized(String ownerUserId, String catalogType);

  /// Marks the catalog [catalogType] as initialized for [ownerUserId].
  Future<void> markInitialized(String ownerUserId, String catalogType);
}
