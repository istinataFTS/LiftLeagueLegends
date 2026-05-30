import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/muscle_stimulus.dart';

/// Repository interface for MuscleStimulus operations.
///
/// All read/write methods that operate on user-specific data require a
/// [userId] parameter — always the authenticated user's uid.
abstract class MuscleStimulusRepository {
  /// Get stimulus for a specific muscle on a specific date.
  Future<Either<Failure, MuscleStimulus?>> getStimulusByMuscleAndDate({
    required String userId,
    required String muscleGroup,
    required DateTime date,
  });

  /// Get all stimulus records for a muscle within a date range.
  Future<Either<Failure, List<MuscleStimulus>>> getStimulusByDateRange({
    required String userId,
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get today's stimulus for a specific muscle.
  Future<Either<Failure, MuscleStimulus?>> getTodayStimulus(
    String userId,
    String muscleGroup,
  );

  /// Get all stimulus records for all muscles on a specific date.
  Future<Either<Failure, List<MuscleStimulus>>> getAllStimulusForDate(
    String userId,
    DateTime date,
  );

  /// Insert or update a stimulus record.
  Future<Either<Failure, void>> upsertStimulus(MuscleStimulus stimulus);

  /// Update stimulus values for an existing record.
  Future<Either<Failure, void>> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  });

  /// Apply daily decay to all muscle records owned by [userId].
  Future<Either<Failure, void>> applyDailyDecayToAll(String userId);

  /// Get maximum daily stimulus ever recorded for a muscle owned by [userId].
  Future<Either<Failure, double>> getMaxStimulusForMuscle(
    String userId,
    String muscleGroup,
  );

  /// Delete stimulus records older than [date] for [userId].
  Future<Either<Failure, void>> deleteOlderThan(String userId, DateTime date);

  /// Clear all stimulus records across every user.
  Future<Either<Failure, void>> clearAllStimulus();

  /// Remove all stimulus records belonging to [userId].
  /// Called on sign-out to prevent cross-profile data leakage.
  Future<Either<Failure, void>> clearStimulusForUser(String userId);
}
