import '../../../domain/entities/workout_set.dart';

abstract class WorkoutSetLocalDataSource {
  Future<List<WorkoutSet>> getAllSets();

  Future<WorkoutSet?> getSetById(String id);

  Future<List<WorkoutSet>> getSetsByExerciseId(String exerciseId);

  Future<List<WorkoutSet>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int? limit,
  });

  Future<List<WorkoutSet>> getPendingSyncSets();

  Future<void> addSet(WorkoutSet set);

  Future<void> updateSet(WorkoutSet set);

  Future<void> upsertSet(WorkoutSet set);

  Future<void> prepareForInitialCloudMigration({required String userId});

  Future<void> replaceAll(List<WorkoutSet> sets);

  Future<void> mergeRemoteSets(List<WorkoutSet> remoteSets);

  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  });

  Future<void> markAsPendingUpload(String localId, {String? errorMessage});

  Future<void> markAsPendingUpdate(String localId, {String? errorMessage});

  Future<void> markAsPendingDelete(String localId, {String? errorMessage});

  Future<void> deleteSet(String id);

  Future<void> clearAllSets();

  Future<void> clearSetsForOwner(String ownerId);
}
