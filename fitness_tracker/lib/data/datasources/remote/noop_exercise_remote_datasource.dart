import '../../../domain/entities/exercise.dart';
import 'exercise_remote_datasource.dart';

class NoopExerciseRemoteDataSource implements ExerciseRemoteDataSource {
  const NoopExerciseRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<List<Exercise>> getAllExercises() async {
    return const <Exercise>[];
  }

  @override
  Future<Exercise?> getExerciseById(String id) async {
    return null;
  }

  @override
  Future<Exercise?> getExerciseByName(String name) async {
    return null;
  }

  @override
  Future<List<Exercise>> getExercisesForMuscle(String muscleGroup) async {
    return const <Exercise>[];
  }

  @override
  Future<Exercise> upsertExercise(Exercise exercise) async {
    return exercise;
  }

  @override
  Future<void> deleteExercise({
    required String localId,
    String? serverId,
  }) async {}

  @override
  Future<List<Exercise>> fetchSince({
    required String userId,
    DateTime? since,
  }) async => const <Exercise>[];
}
