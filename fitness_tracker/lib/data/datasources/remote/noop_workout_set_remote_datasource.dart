import '../../../domain/entities/workout_set.dart';
import 'workout_set_remote_datasource.dart';

class NoopWorkoutSetRemoteDataSource implements WorkoutSetRemoteDataSource {
  const NoopWorkoutSetRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<List<WorkoutSet>> getAllSets() async {
    return const <WorkoutSet>[];
  }

  @override
  Future<WorkoutSet?> getSetById(String id) async {
    return null;
  }

  @override
  Future<WorkoutSet> upsertSet(WorkoutSet set) async {
    return set;
  }

  @override
  Future<void> deleteSet({required String localId, String? serverId}) async {}

  @override
  Future<List<WorkoutSet>> fetchSince({
    required String userId,
    DateTime? since,
  }) async => const <WorkoutSet>[];

  @override
  Future<List<WorkoutSet>> fetchByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int? limit,
  }) async => const <WorkoutSet>[];
}
