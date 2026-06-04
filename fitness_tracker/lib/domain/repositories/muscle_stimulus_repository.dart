import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/muscle_stimulus.dart';

/// Repository interface for MuscleStimulus operations.
///
/// Ownership is resolved by the datasource via the active session.
/// Methods that read or aggregate data do not accept a userId parameter —
/// the datasource always scopes to the current authenticated user.
/// [clearStimulusForUser] retains its parameter because it is called
/// during sign-out for an explicit owner.
abstract class MuscleStimulusRepository {
  /// Get stimulus for a specific muscle on a specific date.
  Future<Either<Failure, MuscleStimulus?>> getStimulusByMuscleAndDate({
    required String muscleGroup,
    required DateTime date,
  });

  /// Get all stimulus records for a muscle within a date range.
  Future<Either<Failure, List<MuscleStimulus>>> getStimulusByDateRange({
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get today's stimulus for a specific muscle.
  Future<Either<Failure, MuscleStimulus?>> getTodayStimulus(String muscleGroup);

  /// Get all stimulus records for all muscles on a specific date.
  Future<Either<Failure, List<MuscleStimulus>>> getAllStimulusForDate(
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

  /// Apply daily decay to all muscle records owned by the current user.
  Future<Either<Failure, void>> applyDailyDecayToAll();

  /// Get maximum daily stimulus ever recorded for a muscle.
  Future<Either<Failure, double>> getMaxStimulusForMuscle(String muscleGroup);

  /// Sum of [daily_volume] for [muscleGroup] owned by the current user,
  /// optionally constrained to [[startDate], [endDate]] inclusive.
  /// Returns 0.0 when no rows match.
  Future<Either<Failure, double>> getTotalVolumeForMuscle(
    String muscleGroup, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Delete stimulus records older than [date].
  Future<Either<Failure, void>> deleteOlderThan(DateTime date);

  /// Clear all stimulus records across every user.
  Future<Either<Failure, void>> clearAllStimulus();

  /// Remove all stimulus records belonging to [userId].
  /// Called on sign-out to prevent cross-profile data leakage.
  Future<Either<Failure, void>> clearStimulusForUser(String userId);
}
