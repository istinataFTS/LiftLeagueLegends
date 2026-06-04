import 'package:dartz/dartz.dart';

import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../entities/muscle_visual_data.dart';
import '../../entities/time_period.dart';
import '../../muscle_visual/muscle_visual_contract.dart';
import '../../muscle_visual/normalized_muscle_load.dart';
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
      final today = _clock.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final aggregationMode = MuscleVisualContract.aggregationModeForPeriod(
        TimePeriod.week,
      );

      final visualData = <String, MuscleVisualData>{};

      for (final muscleGroup in MuscleStimulus.allMuscleGroups) {
        final stimulusResult = await muscleStimulusRepository
            .getStimulusByMuscleAndDate(
              muscleGroup: muscleGroup,
              date: todayStart,
            );

        if (stimulusResult.isLeft()) {
          visualData[muscleGroup] = MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          );
          continue;
        }

        final stimulus = stimulusResult.getOrElse(() => throw StateError(''));

        if (stimulus == null) {
          visualData[muscleGroup] = await _buildWeekDataWithoutToday(
            muscleGroup: muscleGroup,
            todayStart: todayStart,
          );
          continue;
        }

        // For stale rows (row dated in the past — e.g. carried forward by
        // the rebuild but never refreshed), route through
        // [NormalizedMuscleLoad] so the recovery cutoff is the single
        // source of truth. The contract's [classify] only checks
        // `stimulus > 0`, which would paint a muscle whose decayed load
        // had dropped to ~zero as still trained.
        //
        // Fresh same-day rows render directly. The recovery cutoff is
        // calibrated for *aged* loads (~50 % of the weekly threshold);
        // applying it to a brand-new single-set row would hide the
        // muscle the user just trained, because a single set produces a
        // rolling load well below the cutoff at day 0.
        final int daysSince = todayStart
            .difference(
              DateTime(
                stimulus.date.year,
                stimulus.date.month,
                stimulus.date.day,
              ),
            )
            .inDays;

        if (daysSince > 0) {
          final NormalizedMuscleLoad load = NormalizedMuscleLoad(
            raw: stimulus.rollingWeeklyLoad,
            threshold: MuscleStimulus.weeklyThreshold,
          ).decayed(daysSince);

          if (load.isRecovered) {
            visualData[muscleGroup] = MuscleVisualData.untrained(
              muscleGroup,
              aggregationMode: aggregationMode,
            );
            continue;
          }

          visualData[muscleGroup] = _buildVisualData(
            muscleGroup: muscleGroup,
            stimulus: load.raw,
            threshold: load.threshold,
            aggregationMode: aggregationMode,
          );
          continue;
        }

        // daysSince == 0: today's record exists.
        //
        // The rebuild creates carry-forward rows for every muscle through
        // today, even when the last actual set was many days ago. Those rows
        // have a correctly-decayed rollingWeeklyLoad, but without a guard
        // they render as light-green fatigue indefinitely.
        //
        // Use lastSetTimestamp to detect carry-forward rows. If the last
        // actual workout for this muscle was ≥ maxFatigueDays ago, hard-zero
        // it — the same cutoff applied by NormalizedMuscleLoad.decayed().
        // Fresh sets logged today (lastSetTimestamp == today) bypass this
        // check so newly-trained muscles still light up immediately.
        final int daysSinceLastSet = _daysSinceLastSet(
          stimulus.lastSetTimestamp,
          stimulus.date,
          todayStart,
        );
        if (daysSinceLastSet >= MuscleStimulus.maxFatigueDays) {
          visualData[muscleGroup] = MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          );
          continue;
        }

        visualData[muscleGroup] = _buildVisualData(
          muscleGroup: muscleGroup,
          stimulus: stimulus.rollingWeeklyLoad,
          threshold: MuscleStimulus.weeklyThreshold,
          aggregationMode: aggregationMode,
        );
      }

      return Right(visualData);
    } catch (e) {
      return Left(UnexpectedFailure('Failed to get week visual data: $e'));
    }
  }

  Future<Either<Failure, Map<String, MuscleVisualData>>>
  _getMonthVisualData() async {
    try {
      final today = _clock.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final monthAgo = todayStart.subtract(const Duration(days: 30));
      final aggregationMode = MuscleVisualContract.aggregationModeForPeriod(
        TimePeriod.month,
      );

      final visualData = <String, MuscleVisualData>{};

      for (final muscleGroup in MuscleStimulus.allMuscleGroups) {
        final stimulusResult = await muscleStimulusRepository
            .getStimulusByDateRange(
              muscleGroup: muscleGroup,
              startDate: monthAgo,
              endDate: todayStart,
            );

        visualData[muscleGroup] = stimulusResult.fold(
          (_) => MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          ),
          (stimulusList) {
            final monthlyStimulus = stimulusList.fold<double>(
              0.0,
              (sum, stimulus) => sum + stimulus.dailyStimulus,
            );

            return _buildVisualData(
              muscleGroup: muscleGroup,
              stimulus: monthlyStimulus,
              threshold: MuscleStimulus.monthlyThreshold,
              aggregationMode: aggregationMode,
            );
          },
        );
      }

      return Right(visualData);
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

  Future<MuscleVisualData> _buildWeekDataWithoutToday({
    required String muscleGroup,
    required DateTime todayStart,
  }) async {
    final aggregationMode = MuscleVisualContract.aggregationModeForPeriod(
      TimePeriod.week,
    );

    // Look back up to 30 days for the most recent stored record and compute
    // decayedLoad = storedLoad * 0.6^daysSince (passive time-based decay).
    final lookbackStart = todayStart.subtract(const Duration(days: 30));
    final pastRecordsResult = await muscleStimulusRepository
        .getStimulusByDateRange(
          muscleGroup: muscleGroup,
          startDate: lookbackStart,
          endDate: todayStart.subtract(const Duration(days: 1)),
        );

    return pastRecordsResult.fold(
      (_) => MuscleVisualData.untrained(
        muscleGroup,
        aggregationMode: aggregationMode,
      ),
      (records) {
        if (records.isEmpty) {
          return MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          );
        }

        // Records are returned DESC by date — first is most recent.
        final mostRecent = records.first;
        final daysSince = todayStart
            .difference(
              DateTime(
                mostRecent.date.year,
                mostRecent.date.month,
                mostRecent.date.day,
              ),
            )
            .inDays;

        // Route through [NormalizedMuscleLoad] so that both the decay and
        // the recovery comparison happen in consistent units.  The raw
        // rollingWeeklyLoad is ~1–30; [MuscleStimulus.recoveredThreshold]
        // is expressed against the *normalized* 0..1 scale, so comparing
        // raw to threshold directly would leave muscles "fatigued" for
        // days after they have actually recovered.
        final load = NormalizedMuscleLoad(
          raw: mostRecent.rollingWeeklyLoad,
          threshold: MuscleStimulus.weeklyThreshold,
        ).decayed(daysSince);

        if (load.isRecovered) {
          return MuscleVisualData.untrained(
            muscleGroup,
            aggregationMode: aggregationMode,
          );
        }

        return _buildVisualData(
          muscleGroup: muscleGroup,
          stimulus: load.raw,
          threshold: load.threshold,
          aggregationMode: aggregationMode,
        );
      },
    );
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

  /// Returns how many full calendar days have elapsed between [todayStart] and
  /// the date of the last actual set for this muscle, using [lastSetTimestamp]
  /// when available and falling back to [stimulusDate] otherwise.
  static int _daysSinceLastSet(
    int? lastSetTimestamp,
    DateTime stimulusDate,
    DateTime todayStart,
  ) {
    final DateTime lastSetDay;
    if (lastSetTimestamp != null) {
      final raw = DateTime.fromMillisecondsSinceEpoch(lastSetTimestamp);
      lastSetDay = DateTime(raw.year, raw.month, raw.day);
    } else {
      lastSetDay = DateTime(
        stimulusDate.year,
        stimulusDate.month,
        stimulusDate.day,
      );
    }
    final int days = todayStart.difference(lastSetDay).inDays;
    return days < 0 ? 0 : days;
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
