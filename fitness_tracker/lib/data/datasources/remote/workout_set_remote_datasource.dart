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
}
