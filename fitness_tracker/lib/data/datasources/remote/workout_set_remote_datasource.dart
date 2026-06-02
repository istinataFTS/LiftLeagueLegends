import '../../../domain/entities/workout_set.dart';

abstract class WorkoutSetRemoteDataSource {
  bool get isConfigured;

  Future<List<WorkoutSet>> getAllSets();

  Future<WorkoutSet?> getSetById(String id);

  Future<WorkoutSet> upsertSet(WorkoutSet set);

  Future<void> deleteSet({required String localId, String? serverId});

  /// Returns all sets for [userId] whose `updated_at` is after [since].
  /// Pass [since] = null to fetch all sets (e.g. on initial re-login).
  Future<List<WorkoutSet>> fetchSince({
    required String userId,
    DateTime? since,
  });

  /// Returns this user's sets whose `performed_at` is within
  /// [[startDate], [endDate]] (inclusive), newest-first.
  /// Bounds are normalised to UTC at the boundary.
  ///
  /// When [limit] is non-null the server returns at most that many rows
  /// (the most recent ones, given the `performed_at DESC` order).
  Future<List<WorkoutSet>> fetchByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  });
}
