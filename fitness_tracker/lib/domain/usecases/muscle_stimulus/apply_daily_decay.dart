import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../config/env_config.dart';
import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../repositories/muscle_stimulus_repository.dart';

/// Use case for applying daily decay to rolling weekly loads.
class ApplyDailyDecay {
  final MuscleStimulusRepository muscleStimulusRepository;
  final Clock _clock;

  const ApplyDailyDecay(
    this.muscleStimulusRepository, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  Future<Either<Failure, int>> call() async {
    try {
      _logDebug('Starting daily decay application...');

      final result = await muscleStimulusRepository.applyDailyDecayToAll();

      return result.fold(
        (failure) {
          _logError('Failed to apply daily decay: ${failure.message}');
          return Left(failure);
        },
        (_) {
          _logDebug('Daily decay applied successfully');
          return const Right(20); // All muscle groups
        },
      );
    } catch (e) {
      _logError('Exception during daily decay: $e');
      return Left(UnexpectedFailure('Failed to apply daily decay: $e'));
    }
  }

  /// Apply decay for a specific date (for manual corrections).
  Future<Either<Failure, int>> applyDecayForDate(DateTime date) async {
    try {
      _logDebug('Applying decay for date: ${date.toIso8601String()}');

      final dateStart = DateTime(date.year, date.month, date.day);

      final recordsResult = await muscleStimulusRepository
          .getAllStimulusForDate(dateStart);

      return await recordsResult.fold((failure) async => Left(failure), (
        records,
      ) async {
        if (records.isEmpty) {
          _logDebug('No records found for date, skipping decay');
          return const Right(0);
        }

        int updateCount = 0;

        for (final record in records) {
          final newWeeklyLoad =
              record.rollingWeeklyLoad * MuscleStimulus.weeklyDecayFactor;

          final updateResult = await muscleStimulusRepository
              .updateStimulusValues(
                id: record.id,
                dailyStimulus: record.dailyStimulus,
                rollingWeeklyLoad: newWeeklyLoad,
                lastSetTimestamp: record.lastSetTimestamp,
                lastSetStimulus: record.lastSetStimulus,
              );

          updateResult.fold(
            (failure) {
              _logError(
                'Failed to update record ${record.id}: ${failure.message}',
              );
            },
            (_) {
              updateCount++;
            },
          );
        }

        _logDebug('Applied decay to $updateCount records');
        return Right(updateCount);
      });
    } catch (e) {
      _logError('Exception during date-specific decay: $e');
      return Left(UnexpectedFailure('Failed to apply decay for date: $e'));
    }
  }

  /// Check if decay should be applied today.
  Future<Either<Failure, bool>> shouldApplyDecayToday() async {
    try {
      final today = _clock.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final recordsResult = await muscleStimulusRepository
          .getAllStimulusForDate(todayStart);

      return recordsResult.fold((failure) => Left(failure), (records) {
        final shouldApply = records.isEmpty;

        _logDebug(
          'Should apply decay: $shouldApply (${records.length} records found)',
        );

        return Right(shouldApply);
      });
    } catch (e) {
      return Left(UnexpectedFailure('Failed to check decay status: $e'));
    }
  }

  /// Get the decay factor being used.
  double getDecayFactor() {
    return MuscleStimulus.weeklyDecayFactor;
  }

  /// Calculate what a value would be after decay.
  double previewDecay(double currentLoad) {
    return currentLoad * MuscleStimulus.weeklyDecayFactor;
  }

  /// Estimate recovery time for a given stimulus value.
  int estimateRecoveryDays(double currentLoad, {double? threshold}) {
    final targetThreshold = threshold ?? (currentLoad * 0.1);

    if (currentLoad <= targetThreshold) {
      return 0;
    }

    double remainingLoad = currentLoad;
    int days = 0;

    // Simulate daily decay until threshold reached.
    // Cap at 30 days to prevent infinite loops.
    while (remainingLoad > targetThreshold && days < 30) {
      remainingLoad *= MuscleStimulus.weeklyDecayFactor;
      days++;
    }

    return days;
  }

  // ==================== LOGGING HELPERS ====================

  void _logDebug(String message) {
    if (!EnvConfig.enableDebugLogs) return;
    debugPrint('[DAILY_DECAY] $message');
  }

  void _logError(String message) {
    if (!EnvConfig.enableDebugLogs) return;
    debugPrint('[DAILY_DECAY] ERROR: $message');
  }
}
