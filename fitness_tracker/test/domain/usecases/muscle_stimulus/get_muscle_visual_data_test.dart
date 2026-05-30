import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart'
    as stimulus_constants;
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart'
    as stimulus_entity;
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/domain/repositories/muscle_stimulus_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleStimulusRepository extends Mock
    implements MuscleStimulusRepository {}

void main() {
  late MockMuscleStimulusRepository repository;
  late GetMuscleVisualData usecase;

  const String testUserId = 'user-1';

  setUp(() {
    repository = MockMuscleStimulusRepository();
    usecase = GetMuscleVisualData(repository);
  });

  test(
    'today visuals use daily stimulus instead of decayed last-set stimulus',
    () async {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final lastSetTimestamp = today
          .subtract(const Duration(hours: 6))
          .millisecondsSinceEpoch;

      for (final String muscleGroup
          in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        if (muscleGroup == stimulus_constants.MuscleStimulus.quads) {
          when(
            () => repository.getStimulusByMuscleAndDate(
              muscleGroup: muscleGroup,
              date: todayStart,
            ),
          ).thenAnswer(
            (_) async => Right(
              stimulus_entity.MuscleStimulus(
                id: 'quads-today',
                ownerUserId: testUserId,
                muscleGroup: muscleGroup,
                date: todayStart,
                dailyStimulus: 8.0,
                rollingWeeklyLoad: 8.0,
                lastSetTimestamp: lastSetTimestamp,
                lastSetStimulus: 2.0,
                createdAt: todayStart,
                updatedAt: todayStart,
              ),
            ),
          );
        } else {
          when(
            () => repository.getStimulusByMuscleAndDate(
              muscleGroup: muscleGroup,
              date: todayStart,
            ),
          ).thenAnswer((_) async => const Right(null));
        }
      }

      final result = await usecase(TimePeriod.today);
      final visualData = result.getOrElse(
        () => throw StateError('expected data'),
      );
      final quads = visualData[stimulus_constants.MuscleStimulus.quads]!;

      expect(quads.totalStimulus, 8.0);
      expect(quads.bucket, MuscleVisualBucket.maximum);
      expect(quads.coverageState, MuscleVisualCoverageState.full);
    },
  );

  test(
    'returns untrained data for all muscles when user has no stimulus records',
    () async {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      for (final String muscleGroup
          in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));
      }

      final result = await usecase(TimePeriod.today);
      final visualData = result.getOrElse(
        () => throw StateError('expected data'),
      );

      expect(
        visualData.values.every((data) => !data.hasTrained),
        isTrue,
        reason: 'a profile with no workouts should show no muscle activity',
      );
    },
  );

  test(
    'week view classifies a week-old moderate load as recovered — '
    'regression guard for the Lats-are-always-fatigued bug at the use-case level',
    () async {
      // This is the cross-layer counterpart to the NormalizedMuscleLoad unit
      // test: it verifies the fix survives inside GetMuscleVisualData's
      // _buildWeekDataWithoutToday codepath, where the bug originally lived.
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final yesterday = todayStart.subtract(const Duration(days: 1));
      final lookbackStart = todayStart.subtract(const Duration(days: 30));
      final staleRecordDate = todayStart.subtract(const Duration(days: 7));

      // Today: no stimulus records for any muscle — forces every muscle
      // through _buildWeekDataWithoutToday.
      for (final String muscleGroup
          in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));

        // Past 30 days: lats has a 7-day-old moderate load (raw=20,
        // threshold=25).  After `0.6^7 ≈ 0.028` decay the normalized load
        // sits at ~0.022, well below the 0.5 recovery cutoff, so the map
        // must render lats as untrained.  A raw-vs-normalized regression
        // would compare the ~0.56 raw decayed value against 0.5 and
        // incorrectly leave lats fatigued.
        if (muscleGroup == stimulus_constants.MuscleStimulus.lats) {
          when(
            () => repository.getStimulusByDateRange(
              muscleGroup: muscleGroup,
              startDate: lookbackStart,
              endDate: yesterday,
            ),
          ).thenAnswer(
            (_) async => Right(<stimulus_entity.MuscleStimulus>[
              stimulus_entity.MuscleStimulus(
                id: 'lats-stale',
                ownerUserId: testUserId,
                muscleGroup: muscleGroup,
                date: staleRecordDate,
                dailyStimulus: 0,
                rollingWeeklyLoad: 20.0,
                createdAt: staleRecordDate,
                updatedAt: staleRecordDate,
              ),
            ]),
          );
        } else {
          when(
            () => repository.getStimulusByDateRange(
              muscleGroup: muscleGroup,
              startDate: lookbackStart,
              endDate: yesterday,
            ),
          ).thenAnswer(
            (_) async => const Right(<stimulus_entity.MuscleStimulus>[]),
          );
        }
      }

      final result = await usecase(TimePeriod.week);
      final visualData = result.getOrElse(
        () => throw StateError('expected data'),
      );
      final lats = visualData[stimulus_constants.MuscleStimulus.lats]!;

      expect(
        lats.hasTrained,
        isFalse,
        reason:
            'a 7-day-old moderate load must decay below the recovery cutoff; '
            'a unit-mismatch regression would leave lats permanently fatigued',
      );
    },
  );

  test('week view renders a fresh today-row directly without applying the '
      'recovery short-circuit — guards against hiding muscles the user just '
      'trained', () async {
    // Regression for the "Volume/Week + Fatigue both empty after logging"
    // bug: a single fresh set produces a rolling weekly load well below
    // 0.5 * weeklyThreshold (12.5). If the today-branch applies the
    // recovery cutoff to *fresh* rows it hides the muscle the user just
    // trained. The cutoff is meant for aged rows only, so a row dated
    // today (daysSince == 0) must render directly.
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    for (final String muscleGroup
        in stimulus_constants.MuscleStimulus.allMuscleGroups) {
      if (muscleGroup == stimulus_constants.MuscleStimulus.lats) {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'lats-today-fresh',
              ownerUserId: testUserId,
              muscleGroup: muscleGroup,
              date: todayStart,
              dailyStimulus: 4.0,
              // Below 0.5 * weeklyThreshold (12.5). Old behaviour would
              // hide this; the fix renders it because daysSince == 0.
              rollingWeeklyLoad: 4.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );
      } else {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => repository.getStimulusByDateRange(
            muscleGroup: muscleGroup,
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer(
          (_) async => const Right(<stimulus_entity.MuscleStimulus>[]),
        );
      }
    }

    final result = await usecase(TimePeriod.week);
    final visualData = result.getOrElse(
      () => throw StateError('expected data'),
    );

    final lats = visualData[stimulus_constants.MuscleStimulus.lats]!;
    expect(
      lats.hasTrained,
      isTrue,
      reason:
          'a fresh today-row must render even when its rolling load is '
          'below the recovery cutoff — the cutoff is calibrated for aged '
          'loads, not for the first set of the day',
    );
    expect(lats.totalStimulus, 4.0);
  });

  test('week view applies decay to a stale-dated today-branch row using '
      'days-since-the-row-date', () async {
    // If a stimulus row is dated several days in the past (e.g. the rebuild
    // never ran or a future regression stops propagating rows forward),
    // the today-branch must still age the load by `today - row.date` and
    // hand off to isRecovered. With raw=20 and 5 days of decay
    // (0.6^5 ≈ 0.0778) the normalized load drops to ~0.062 — well under
    // the 0.5 cutoff.
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final fiveDaysAgo = todayStart.subtract(const Duration(days: 5));

    for (final String muscleGroup
        in stimulus_constants.MuscleStimulus.allMuscleGroups) {
      if (muscleGroup == stimulus_constants.MuscleStimulus.midChest) {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'chest-stale-today',
              ownerUserId: testUserId,
              muscleGroup: muscleGroup,
              date: fiveDaysAgo,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 20.0,
              createdAt: fiveDaysAgo,
              updatedAt: fiveDaysAgo,
            ),
          ),
        );
      } else {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: muscleGroup,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => repository.getStimulusByDateRange(
            muscleGroup: muscleGroup,
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer(
          (_) async => const Right(<stimulus_entity.MuscleStimulus>[]),
        );
      }
    }

    final result = await usecase(TimePeriod.week);
    final visualData = result.getOrElse(
      () => throw StateError('expected data'),
    );

    expect(
      visualData[stimulus_constants.MuscleStimulus.midChest]!.hasTrained,
      isFalse,
    );
  });
}
