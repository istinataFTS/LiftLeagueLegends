import '../../../domain/entities/exercise.dart';

abstract class ExerciseRemoteDataSource {
  bool get isConfigured;

  Future<List<Exercise>> getAllExercises();

  Future<Exercise?> getExerciseById(String id);

  Future<Exercise?> getExerciseByName(String name);

  Future<List<Exercise>> getExercisesForMuscle(String muscleGroup);

  Future<Exercise> upsertExercise(Exercise exercise);

  Future<void> deleteExercise({required String localId, String? serverId});

  /// Returns all user-owned exercises whose `updated_at` is after [since].
  /// Pass [since] = null to fetch all exercises (e.g. on initial re-login).
  Future<List<Exercise>> fetchSince({required String userId, DateTime? since});
}
