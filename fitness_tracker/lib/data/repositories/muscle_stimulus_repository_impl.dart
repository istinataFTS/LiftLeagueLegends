import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../domain/entities/muscle_stimulus.dart';
import '../../domain/repositories/muscle_stimulus_repository.dart';
import '../datasources/local/muscle_stimulus_local_datasource.dart';
import '../models/muscle_stimulus_model.dart';

/// Repository implementation for MuscleStimulus operations.
/// Uses [RepositoryGuard] to keep failure mapping consistent across methods.
class MuscleStimulusRepositoryImpl implements MuscleStimulusRepository {
  final MuscleStimulusLocalDataSource localDataSource;

  const MuscleStimulusRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, MuscleStimulus?>> getStimulusByMuscleAndDate({
    required String userId,
    required String muscleGroup,
    required DateTime date,
  }) {
    return RepositoryGuard.run(() async {
      return localDataSource.getStimulusByMuscleAndDate(
        muscleGroup: muscleGroup,
        date: date,
      );
    });
  }

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getStimulusByDateRange({
    required String userId,
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return RepositoryGuard.run(() async {
      return localDataSource.getStimulusByDateRange(
        muscleGroup: muscleGroup,
        startDate: startDate,
        endDate: endDate,
      );
    });
  }

  @override
  Future<Either<Failure, MuscleStimulus?>> getTodayStimulus(
    String userId,
    String muscleGroup,
  ) {
    return RepositoryGuard.run(() async {
      return localDataSource.getTodayStimulus(muscleGroup);
    });
  }

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getAllStimulusForDate(
    String userId,
    DateTime date,
  ) {
    return RepositoryGuard.run(() async {
      return localDataSource.getAllStimulusForDate(date);
    });
  }

  @override
  Future<Either<Failure, void>> upsertStimulus(MuscleStimulus stimulus) {
    return RepositoryGuard.run(() async {
      final MuscleStimulusModel model = MuscleStimulusModel.fromEntity(
        stimulus,
      );
      await localDataSource.upsertStimulus(model);
    });
  }

  @override
  Future<Either<Failure, void>> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  }) {
    return RepositoryGuard.run(() async {
      await localDataSource.updateStimulusValues(
        id: id,
        dailyStimulus: dailyStimulus,
        rollingWeeklyLoad: rollingWeeklyLoad,
        lastSetTimestamp: lastSetTimestamp,
        lastSetStimulus: lastSetStimulus,
      );
    });
  }

  @override
  Future<Either<Failure, void>> applyDailyDecayToAll(String userId) {
    return RepositoryGuard.run(() async {
      await localDataSource.applyDailyDecayToAll();
    });
  }

  @override
  Future<Either<Failure, double>> getMaxStimulusForMuscle(
    String userId,
    String muscleGroup,
  ) {
    return RepositoryGuard.run(() async {
      return localDataSource.getMaxStimulusForMuscle(muscleGroup);
    });
  }

  @override
  Future<Either<Failure, void>> deleteOlderThan(String userId, DateTime date) {
    return RepositoryGuard.run(() async {
      await localDataSource.deleteOlderThan(date);
    });
  }

  @override
  Future<Either<Failure, void>> clearAllStimulus() {
    return RepositoryGuard.run(() async {
      await localDataSource.clearAllStimulus();
    });
  }

  @override
  Future<Either<Failure, void>> clearStimulusForUser(String userId) {
    return RepositoryGuard.run(() async {
      await localDataSource.clearStimulusForUser(userId);
    });
  }
}
