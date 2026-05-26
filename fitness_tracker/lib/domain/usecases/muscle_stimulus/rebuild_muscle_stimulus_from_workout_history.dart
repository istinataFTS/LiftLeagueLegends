import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/data_source_preference.dart';
import '../../../core/errors/failures.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../entities/muscle_stimulus.dart';
import '../../entities/stimulus_calculation_rules.dart';
import '../../entities/workout_set.dart';
import '../../repositories/muscle_stimulus_repository.dart';
import '../../repositories/workout_set_repository.dart';
import 'calculate_muscle_stimulus.dart';

class RebuildMuscleStimulusFromWorkoutHistory {
  RebuildMuscleStimulusFromWorkoutHistory({
    required this.workoutSetRepository,
    required this.muscleStimulusRepository,
    required this.calculateMuscleStimulus,
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  final WorkoutSetRepository workoutSetRepository;
  final MuscleStimulusRepository muscleStimulusRepository;
  final CalculateMuscleStimulus calculateMuscleStimulus;
  final Clock _clock;
  final Uuid _uuid = const Uuid();

  /// Rebuilds all muscle stimulus records for [userId] from their full workout
  /// history.  Only the records belonging to [userId] are cleared and
  /// re-generated — other users' data is never touched.
  Future<Either<Failure, void>> call(String userId) async {
    final workoutSetsResult = await workoutSetRepository.getAllSets(
      sourcePreference: DataSourcePreference.localOnly,
    );

    return workoutSetsResult.fold((failure) async => Left(failure), (
      workoutSets,
    ) async {
      final recordsResult = await _buildRecords(userId, workoutSets);

      return recordsResult.fold((failure) async => Left(failure), (
        records,
      ) async {
        // Clears only the current user's records, leaving other profiles intact.
        final clearResult = await muscleStimulusRepository.clearStimulusForUser(
          userId,
        );

        return clearResult.fold((failure) async => Left(failure), (_) async {
          for (final record in records) {
            final upsertResult = await muscleStimulusRepository.upsertStimulus(
              record,
            );
            if (upsertResult.isLeft()) {
              return upsertResult;
            }
          }

          return const Right(null);
        });
      });
    });
  }

  Future<Either<Failure, List<MuscleStimulus>>> _buildRecords(
    String userId,
    List<WorkoutSet> workoutSets,
  ) async {
    if (workoutSets.isEmpty) {
      return const Right(<MuscleStimulus>[]);
    }

    final sortedSets = [...workoutSets]
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

    final dailyStimulusByDate = <DateTime, Map<String, double>>{};
    final lastSetByDate = <DateTime, Map<String, _StimulusSetMeta>>{};

    for (final workoutSet in sortedSets) {
      final stimulusResult = await calculateMuscleStimulus.calculateForSet(
        exerciseId: workoutSet.exerciseId,
        sets: 1,
        intensity: workoutSet.intensity,
      );

      final muscleStimuli = stimulusResult.fold<Map<String, double>?>(
        (failure) => null,
        (value) => value,
      );

      if (muscleStimuli == null) {
        return Left(
          stimulusResult.swap().getOrElse(
            () => const UnexpectedFailure('Failed to calculate stimulus'),
          ),
        );
      }

      final day = _startOfDay(workoutSet.date);
      final dayStimulus = dailyStimulusByDate.putIfAbsent(
        day,
        () => <String, double>{},
      );
      final dayLastSet = lastSetByDate.putIfAbsent(
        day,
        () => <String, _StimulusSetMeta>{},
      );

      for (final entry in muscleStimuli.entries) {
        dayStimulus[entry.key] = (dayStimulus[entry.key] ?? 0.0) + entry.value;

        final existingMeta = dayLastSet[entry.key];
        if (existingMeta == null ||
            workoutSet.date.millisecondsSinceEpoch >= existingMeta.timestamp) {
          dayLastSet[entry.key] = _StimulusSetMeta(
            timestamp: workoutSet.date.millisecondsSinceEpoch,
            stimulus: entry.value,
          );
        }
      }
    }

    final earliestDay = _startOfDay(sortedSets.first.date);
    final latestWorkoutDay = _startOfDay(sortedSets.last.date);
    final today = _startOfDay(_clock.now());
    final finalDay = latestWorkoutDay.isAfter(today) ? latestWorkoutDay : today;

    final records = <MuscleStimulus>[];
    final previousRollingLoad = <String, double>{};
    final latestSetMeta = <String, _StimulusSetMeta>{};

    for (
      DateTime day = earliestDay;
      !day.isAfter(finalDay);
      day = day.add(const Duration(days: 1))
    ) {
      final dayStimulus = dailyStimulusByDate[day] ?? const <String, double>{};
      final dayLastSet =
          lastSetByDate[day] ?? const <String, _StimulusSetMeta>{};

      final musclesForDay = <String>{
        ...previousRollingLoad.keys,
        ...dayStimulus.keys,
        ...dayLastSet.keys,
      };

      for (final muscleGroup in musclesForDay) {
        final stimulus = dayStimulus[muscleGroup] ?? 0.0;
        final rollingWeeklyLoad =
            StimulusCalculationRules.calculateRollingWeeklyLoad(
              previousWeeklyLoad: previousRollingLoad[muscleGroup] ?? 0.0,
              dailyStimulus: stimulus,
            );

        final latestForDay = dayLastSet[muscleGroup];
        if (latestForDay != null) {
          latestSetMeta[muscleGroup] = latestForDay;
        }

        final carriedMeta = latestSetMeta[muscleGroup];

        records.add(
          MuscleStimulus(
            id: _uuid.v4(),
            ownerUserId: userId,
            muscleGroup: muscleGroup,
            date: day,
            dailyStimulus: stimulus,
            rollingWeeklyLoad: rollingWeeklyLoad,
            lastSetTimestamp: carriedMeta?.timestamp,
            lastSetStimulus: carriedMeta?.stimulus,
            createdAt: day,
            updatedAt: day,
          ),
        );

        previousRollingLoad[muscleGroup] = rollingWeeklyLoad;
      }
    }

    return Right(records);
  }
}

class _StimulusSetMeta {
  const _StimulusSetMeta({required this.timestamp, required this.stimulus});

  final int timestamp;
  final double stimulus;
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
