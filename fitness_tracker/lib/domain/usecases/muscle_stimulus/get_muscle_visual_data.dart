import 'package:dartz/dartz.dart';

import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../../core/utils/calendar_day.dart';
import '../../entities/muscle_visual_data.dart';
import '../../entities/stimulus_calculation_rules.dart';
import '../../entities/time_period.dart';
import '../../muscle_visual/muscle_visual_contract.dart';
import '../../repositories/muscle_stimulus_repository.dart';

class GetMuscleVisualData {
  final MuscleStimulusRepository muscleStimulusRepository;
  final Clock _clock;

  const GetMuscleVisualData(
    this.muscleStimulusRepository, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  Future<Either<Failure, Map<String, MuscleVisualData>>> call(
    TimePeriod period,
  ) async {
    try {
      switch (period) {
        case TimePeriod.today:
          return _getTodayVisualData();
        case TimePeriod.week:
          return _getWeekVisualData();
        case TimePeriod.month:
          return _getMonthVisualData();
        case TimePeriod.allTime:
          return _getAllTimeVisualData();
      }
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get visual data: $e'));
    }
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  _getTodayVisualData() async {
    try {
      final today = _clock.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final aggregationMode = MuscleVisualContract.aggregationModeForPeriod(
        TimePeriod.today,
      );

      final visualData = <String, MuscleVisualData>{};

      for (final muscleGroup in MuscleStimulus.allMuscleGroups) {
        final stimulusResult = await muscleStimulusRepository
            .getStimulusByMuscleAndDate(
              muscleGroup: muscleGroup,
              date: todayStart,
            );

        visualData[muscleGroup] = stimulusResult.fold(
          (_) => MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          ),
          (stimulus) {
            if (stimulus == null) {
              return MuscleVisualData.untrained(
                muscleGroup,
                aggregationMode: aggregationMode,
              );
            }

            return _buildVisualData(
              muscleGroup: muscleGroup,
              stimulus: stimulus.dailyStimulus,
              threshold: MuscleStimulus.dailyThreshold,
              aggregationMode: aggregationMode,
            );
          },
        );
      }

      return Right(visualData);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get today visual data: $e'));
    }
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  _getWeekVisualData() async {
    try {
      final now = _clock.now();
      final todayStart = CalendarDay.startOfDay(now);
      final mode = MuscleVisualContract.aggregationModeForPeriod(
        TimePeriod.week,
      );
      final visual = <String, MuscleVisualData>{};

      for (final muscle in MuscleStimulus.allMuscleGroups) {
        final rowResult = await muscleStimulusRepository
            .getStimulusByMuscleAndDate(muscleGroup: muscle, date: todayStart);

        // Propagate repository failures — silently treating them as untrained
        // would hide real errors on the default (fatigue) view.
        if (rowResult.isLeft()) {
          return rowResult.fold(
            (failure) => Left(failure),
            (_) => throw StateError('unreachable'),
          );
        }

        final row = rowResult.getOrElse(() => null);

        if (row == null ||
            row.fatigueAnchorTimestamp == null ||
            row.fatigueScore <= 0) {
          visual[muscle] = MuscleVisualData.untrained(
            muscle,
            aggregationMode: mode,
          );
          continue;
        }

        final anchorDay = CalendarDay.startOfDay(
          DateTime.fromMillisecondsSinceEpoch(row.fatigueAnchorTimestamp!),
        );
        final daysSince = CalendarDay.calendarDaysBetween(
          anchorDay,
          todayStart,
        );
        final current = StimulusCalculationRules.decayFatigue(
          row.fatigueScore,
          daysSince,
        );

        visual[muscle] = current <= 0
            ? MuscleVisualData.untrained(muscle, aggregationMode: mode)
            : MuscleVisualData.fromFatigue(
                muscleGroup: muscle,
                fatigue: current,
                aggregationMode: mode,
              );
      }
      return Right(visual);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get fatigue visual data: $e'));
    }
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  _getMonthVisualData() async {
    try {
      final now = _clock.now();
      // Calendar-month window: 1st of month (local midnight) → today (inclusive).
      final monthStart = DateTime(now.year, now.month, 1);
      final todayStart = CalendarDay.startOfDay(now);

      final totals = <String, double>{};
      for (final m in MuscleStimulus.allMuscleGroups) {
        totals[m] = (await muscleStimulusRepository.getTotalVolumeForMuscle(
          m,
          startDate: monthStart,
          endDate: todayStart,
        )).getOrElse(() => 0.0);
      }

      return Right(
        _buildRelativeVolumeData(
          totals,
          MuscleVisualContract.aggregationModeForPeriod(TimePeriod.month),
        ),
      );
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get month visual data: $e'));
    }
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  _getAllTimeVisualData() async {
    try {
      // All-time: each muscle ranked by its lifetime total volume (Σ
      // daily_volume) relative to the most-trained muscle.  Previously used
      // peak single-day daily_stimulus; now uses total volume so heavier,
      // higher-rep muscles correctly outrank lower-volume muscles.
      final totals = <String, double>{};
      for (final m in MuscleStimulus.allMuscleGroups) {
        totals[m] = (await muscleStimulusRepository.getTotalVolumeForMuscle(
          m,
        )).getOrElse(() => 0.0);
      }

      return Right(
        _buildRelativeVolumeData(
          totals,
          MuscleVisualContract.aggregationModeForPeriod(TimePeriod.allTime),
        ),
      );
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get all time visual data: $e'));
    }
  }

  /// Builds a relative-volume map: the muscle with the highest total is
  /// normalised to 1.0 (red); all others scale proportionally; 0-volume
  /// muscles render as [MuscleVisualData.untrained] (gray).
  ///
  /// Shared by All-time (full history) and Month (calendar-month window).
  Map<String, MuscleVisualData> _buildRelativeVolumeData(
    Map<String, double> totalsByMuscle,
    MuscleVisualAggregationMode mode,
  ) {
    final maxTotal = totalsByMuscle.values.fold<double>(
      0.0,
      (a, b) => b > a ? b : a,
    );
    // Avoid division by zero when no sets have ever been logged.
    final threshold = maxTotal > 0 ? maxTotal : 1.0;

    return {
      for (final entry in totalsByMuscle.entries)
        entry.key: entry.value <= 0
            ? MuscleVisualData.untrained(entry.key, aggregationMode: mode)
            : MuscleVisualData.fromStimulus(
                muscleGroup: entry.key,
                stimulus: entry.value,
                threshold: threshold,
                aggregationMode: mode,
              ),
    };
  }

  MuscleVisualData _buildVisualData({
    required String muscleGroup,
    required double stimulus,
    required double threshold,
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    return MuscleVisualData.fromStimulus(
      muscleGroup: muscleGroup,
      stimulus: stimulus,
      threshold: threshold,
      aggregationMode: aggregationMode,
    );
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  getVisualDataForMuscles(TimePeriod period, List<String> muscleGroups) async {
    final allDataResult = await call(period);

    return allDataResult.fold((failure) => Left(failure), (allData) {
      final filteredData = <String, MuscleVisualData>{};

      for (final muscleGroup in muscleGroups) {
        if (allData.containsKey(muscleGroup)) {
          filteredData[muscleGroup] = allData[muscleGroup]!;
        }
      }

      return Right(filteredData);
    });
  }
}
