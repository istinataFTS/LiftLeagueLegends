import 'dart:math' show pow;

import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../config/env_config.dart';
import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../entities/muscle_stimulus.dart' as muscle_stimulus_entity;
import '../../repositories/muscle_factor_repository.dart';
import '../../repositories/muscle_stimulus_repository.dart';
import 'calculate_muscle_stimulus.dart';

/// Use case for recording a workout set and updating muscle stimulus.
class RecordWorkoutSet {
  final MuscleFactorRepository muscleFactorRepository;
  final MuscleStimulusRepository muscleStimulusRepository;
  final CalculateMuscleStimulus calculateMuscleStimulus;
  final Clock _clock;
  final _uuid = const Uuid();

  RecordWorkoutSet({
    required this.muscleFactorRepository,
    required this.muscleStimulusRepository,
    required this.calculateMuscleStimulus,
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  Future<Either<Failure, List<String>>> call({
    required String userId,
    required String exerciseId,
    required int sets,
    required int intensity,
    DateTime? timestamp,
  }) async {
    try {
      final setTimestamp = timestamp ?? _clock.now();
      final now = _clock.now();

      final stimulusResult = await calculateMuscleStimulus.calculateForSet(
        exerciseId: exerciseId,
        sets: sets,
        intensity: intensity,
      );

      return await stimulusResult.fold((failure) async => Left(failure), (
        muscleStimuli,
      ) async {
        if (muscleStimuli.isEmpty) {
          // No factors matched this exercise — the workout_set is already
          // persisted, but the body map will have nothing to highlight.
          // `CalculateMuscleStimulus` has logged the root cause; we log
          // here too so the call site (bloc + UI) is greppable.
          AppLogger.warning(
            'No muscle mapping applied for exerciseId=$exerciseId '
            '(userId=$userId).  Check that muscle factors are seeded '
            'for this exercise.',
            category: 'stimulus',
          );
          return const Right([]);
        }

        final affectedMuscles = <String>[];

        for (final entry in muscleStimuli.entries) {
          final muscleGroup = entry.key;
          final setStimulus = entry.value;

          final updateResult = await _updateMuscleStimulus(
            userId: userId,
            muscleGroup: muscleGroup,
            setStimulus: setStimulus,
            setTimestamp: setTimestamp.millisecondsSinceEpoch,
            now: now,
          );

          updateResult.fold(
            (failure) {
              if (EnvConfig.enableDebugLogs) {
                AppLogger.debug(
                  'Failed to update stimulus for $muscleGroup: ${failure.message}',
                  category: 'stimulus',
                );
              }
            },
            (_) {
              affectedMuscles.add(muscleGroup);
            },
          );
        }

        return Right(affectedMuscles);
      });
    } catch (e) {
      return Left(UnexpectedFailure('Failed to record workout set: $e'));
    }
  }

  Future<Either<Failure, void>> _updateMuscleStimulus({
    required String userId,
    required String muscleGroup,
    required double setStimulus,
    required int setTimestamp,
    required DateTime now,
  }) async {
    try {
      // Derive the stimulus date from the set's own timestamp so that
      // back-filled historical sets (logged via the History page) land on
      // the correct date instead of today's date.
      final setDate = DateTime.fromMillisecondsSinceEpoch(setTimestamp);
      final today = DateTime(setDate.year, setDate.month, setDate.day);

      final existingResult = await muscleStimulusRepository
          .getStimulusByMuscleAndDate(
            userId: userId,
            muscleGroup: muscleGroup,
            date: today,
          );

      return await existingResult.fold((failure) async => Left(failure), (
        existingStimulus,
      ) async {
        if (existingStimulus == null) {
          return _createNewStimulusRecord(
            userId: userId,
            muscleGroup: muscleGroup,
            setStimulus: setStimulus,
            setTimestamp: setTimestamp,
            date: today,
          );
        } else {
          return _updateExistingStimulusRecord(
            existing: existingStimulus,
            setStimulus: setStimulus,
            setTimestamp: setTimestamp,
          );
        }
      });
    } catch (e) {
      return Left(UnexpectedFailure('Failed to update muscle stimulus: $e'));
    }
  }

  Future<Either<Failure, void>> _createNewStimulusRecord({
    required String userId,
    required String muscleGroup,
    required double setStimulus,
    required int setTimestamp,
    required DateTime date,
  }) async {
    try {
      // Look back up to 30 days for the most recent stored record and apply
      // time-based decay: decayedLoad = storedLoad * 0.6^daysSince.
      // This avoids any batch-decay mutations and correctly handles multi-day gaps.
      final lookbackStart = date.subtract(const Duration(days: 30));
      final pastRecordsResult = await muscleStimulusRepository
          .getStimulusByDateRange(
            userId: userId,
            muscleGroup: muscleGroup,
            startDate: lookbackStart,
            endDate: date.subtract(const Duration(days: 1)),
          );

      double previousDecayedLoad = 0.0;
      pastRecordsResult.fold((_) {}, (records) {
        if (records.isNotEmpty) {
          // Records are returned DESC by date, so first = most recent.
          final mostRecent = records.first;
          final daysSince = date
              .difference(
                DateTime(
                  mostRecent.date.year,
                  mostRecent.date.month,
                  mostRecent.date.day,
                ),
              )
              .inDays;
          previousDecayedLoad =
              mostRecent.rollingWeeklyLoad *
              pow(MuscleStimulus.weeklyDecayFactor, daysSince).toDouble();
        }
      });

      final newWeeklyLoad = previousDecayedLoad + setStimulus;

      final stimulus = muscle_stimulus_entity.MuscleStimulus(
        id: _uuid.v4(),
        ownerUserId: userId,
        muscleGroup: muscleGroup,
        date: date,
        dailyStimulus: setStimulus,
        rollingWeeklyLoad: newWeeklyLoad,
        lastSetTimestamp: setTimestamp,
        lastSetStimulus: setStimulus,
        createdAt: _clock.now(),
        updatedAt: _clock.now(),
      );

      return await muscleStimulusRepository.upsertStimulus(stimulus);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to create stimulus record: $e'));
    }
  }

  Future<Either<Failure, void>> _updateExistingStimulusRecord({
    required muscle_stimulus_entity.MuscleStimulus existing,
    required double setStimulus,
    required int setTimestamp,
  }) async {
    try {
      final newDailyStimulus = existing.dailyStimulus + setStimulus;
      final newWeeklyLoad = existing.rollingWeeklyLoad + setStimulus;

      return await muscleStimulusRepository.updateStimulusValues(
        id: existing.id,
        dailyStimulus: newDailyStimulus,
        rollingWeeklyLoad: newWeeklyLoad,
        lastSetTimestamp: setTimestamp,
        lastSetStimulus: setStimulus,
      );
    } catch (e) {
      return Left(UnexpectedFailure('Failed to update stimulus record: $e'));
    }
  }

  bool validateInputs({
    required String exerciseId,
    required int sets,
    required int intensity,
  }) {
    return calculateMuscleStimulus.validateInputs(
      exerciseId: exerciseId,
      sets: sets,
      intensity: intensity,
    );
  }
}
