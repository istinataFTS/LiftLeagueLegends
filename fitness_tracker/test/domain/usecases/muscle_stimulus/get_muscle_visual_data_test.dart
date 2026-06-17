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

import '../../../integration/support/fake_clock.dart';

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

  // ---------------------------------------------------------------------------
  // Fatigue path (TimePeriod.week → new 0–100 fatigue model)
  // ---------------------------------------------------------------------------
  //
  // Fixed clock: 2026-06-15. The rebuild guarantees a today row for every
  // ever-trained muscle, so getStimulusByMuscleAndDate(today) is the only
  // repository call the new path makes.

  group('Fatigue path (TimePeriod.week)', () {
    final fixedNow = DateTime(2026, 6, 15);
    final todayStart = DateTime(2026, 6, 15);

    late GetMuscleVisualData usecaseWithClock;

    setUp(() {
      usecaseWithClock = GetMuscleVisualData(
        repository,
        clock: FakeClock(fixedNow),
      );
    });

    /// Stubs every non-target muscle to return Right(null).
    void stubOtherMuscles(String targetMuscle) {
      for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        if (m == targetMuscle) continue;
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: m,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));
      }
    }

    test(
      'fatigue_score=70, fatigueAnchorTimestamp=today → current≈70 → heavy bucket (orange)',
      () async {
        const targetMuscle = stimulus_constants.MuscleStimulus.quads;
        stubOtherMuscles(targetMuscle);

        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: targetMuscle,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'quads-today',
              ownerUserId: testUserId,
              muscleGroup: targetMuscle,
              date: todayStart,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 0.0,
              lastSetTimestamp: todayStart.millisecondsSinceEpoch,
              fatigueAnchorTimestamp: todayStart.millisecondsSinceEpoch,
              fatigueScore: 70.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );

        final result = await usecaseWithClock(TimePeriod.week);
        final data = result.getOrElse(() => throw StateError('expected data'));
        final quads = data[targetMuscle]!;

        // daysSince = 0 → decayFatigue(70, 0) = 70 → 70/100 = 0.7 → [0.6,0.8) → heavy
        expect(quads.hasTrained, isTrue);
        expect(quads.bucket, MuscleVisualBucket.heavy);
      },
    );

    test(
      'fatigue_score=70, fatigueAnchorTimestamp=2 days ago → decayed to ~33 → light bucket (green)',
      () async {
        const targetMuscle = stimulus_constants.MuscleStimulus.lats;
        final twoDaysAgo = DateTime(2026, 6, 13);
        stubOtherMuscles(targetMuscle);

        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: targetMuscle,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'lats-today',
              ownerUserId: testUserId,
              muscleGroup: targetMuscle,
              date: todayStart,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 0.0,
              lastSetTimestamp: twoDaysAgo.millisecondsSinceEpoch,
              fatigueAnchorTimestamp: twoDaysAgo.millisecondsSinceEpoch,
              fatigueScore: 70.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );

        final result = await usecaseWithClock(TimePeriod.week);
        final data = result.getOrElse(() => throw StateError('expected data'));
        final lats = data[targetMuscle]!;

        // daysSince = 2 → 70 * exp(-(0.25*2 + 0.06*4)) = 70 * exp(-0.74) ≈ 33.4
        // 33.4/100 = 0.334 → [0.2, 0.4) → light
        expect(lats.hasTrained, isTrue);
        expect(lats.bucket, MuscleVisualBucket.light);
      },
    );

    // Regression: bodyweight set advances lastSetTimestamp (2026-06-13) but anchor
    // stays at the last weighted day (2026-06-09).  The read must decay from the
    // anchor (6 days), not lastSetTimestamp (2 days).
    test(
      'anchor decoupling: fatigueScore=60, anchor=2026-06-09, lastSetTimestamp=2026-06-13, '
      'today=2026-06-15 → decays from anchor (6 days), not lastSetTimestamp (2 days)',
      () async {
        const targetMuscle = stimulus_constants.MuscleStimulus.chest;
        // Fixed clock: 2026-06-15. Anchor=2026-06-09, last-set=2026-06-13.
        final anchorDay = DateTime(2026, 6, 9);
        final lastSetDay = DateTime(2026, 6, 13);
        stubOtherMuscles(targetMuscle);

        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: targetMuscle,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'chest-today',
              ownerUserId: testUserId,
              muscleGroup: targetMuscle,
              date: todayStart,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 0.0,
              lastSetTimestamp: lastSetDay.millisecondsSinceEpoch,
              fatigueAnchorTimestamp: anchorDay.millisecondsSinceEpoch,
              fatigueScore: 60.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );

        final result = await usecaseWithClock(TimePeriod.week);
        final data = result.getOrElse(() => throw StateError('expected data'));
        final chest = data[targetMuscle]!;

        // From 2026-06-09 to 2026-06-15 = 6 days.
        // From 2026-06-13 to 2026-06-15 = 2 days.
        // decayFatigue(60, 6) must be used, NOT decayFatigue(60, 2).
        // decayFatigue(60, 2): 60 * exp(-(0.25*2 + 0.06*4)) ≈ 28.6 → light
        // decayFatigue(60, 6): 60 * exp(-(0.25*6 + 0.06*36)) ≈ 3.2 → below mild → untrained
        // So the regression is: if decay uses anchor(2026-06-09) → hasTrained==false (recovered).
        //                        if decay uses lastSet(2026-06-13) → hasTrained==true (orange-ish).
        expect(
          chest.hasTrained,
          isFalse,
          reason:
              'decay from anchor (2026-06-09 / Tuesday, 6 days) must yield near-zero '
              'fatigue → recovered/gray; decaying from lastSetTimestamp '
              '(2026-06-13 / Saturday, 2 days) would incorrectly show the muscle as trained',
        );
      },
    );

    test(
      'fatigue_score=10 (below 20 band) → hasTrained false (recovered/gray)',
      () async {
        const targetMuscle = stimulus_constants.MuscleStimulus.biceps;
        stubOtherMuscles(targetMuscle);

        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: targetMuscle,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'biceps-today',
              ownerUserId: testUserId,
              muscleGroup: targetMuscle,
              date: todayStart,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 0.0,
              lastSetTimestamp: todayStart.millisecondsSinceEpoch,
              fatigueAnchorTimestamp: todayStart.millisecondsSinceEpoch,
              fatigueScore: 10.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );

        final result = await usecaseWithClock(TimePeriod.week);
        final data = result.getOrElse(() => throw StateError('expected data'));

        // 10/100 = 0.10 < 0.20 (fatigueBandMild) → hasTrained = false
        expect(data[targetMuscle]!.hasTrained, isFalse);
      },
    );

    test('no row for muscle (Right(null)) → untrained/gray', () async {
      for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: m,
            date: todayStart,
          ),
        ).thenAnswer((_) async => const Right(null));
      }

      final result = await usecaseWithClock(TimePeriod.week);
      final data = result.getOrElse(() => throw StateError('expected data'));

      expect(
        data.values.every((d) => !d.hasTrained),
        isTrue,
        reason: 'no rows → every muscle untrained',
      );
    });

    test('row with fatigueScore=0 → short-circuits to untrained', () async {
      const targetMuscle = stimulus_constants.MuscleStimulus.triceps;
      stubOtherMuscles(targetMuscle);

      when(
        () => repository.getStimulusByMuscleAndDate(
          muscleGroup: targetMuscle,
          date: todayStart,
        ),
      ).thenAnswer(
        (_) async => Right(
          stimulus_entity.MuscleStimulus(
            id: 'triceps-today',
            ownerUserId: testUserId,
            muscleGroup: targetMuscle,
            date: todayStart,
            dailyStimulus: 0.0,
            rollingWeeklyLoad: 0.0,
            lastSetTimestamp: todayStart.millisecondsSinceEpoch,
            fatigueAnchorTimestamp: todayStart.millisecondsSinceEpoch,
            fatigueScore: 0.0,
            createdAt: todayStart,
            updatedAt: todayStart,
          ),
        ),
      );

      final result = await usecaseWithClock(TimePeriod.week);
      final data = result.getOrElse(() => throw StateError('expected data'));

      expect(data[targetMuscle]!.hasTrained, isFalse);
    });

    test(
      'row with fatigueAnchorTimestamp=null → short-circuits to untrained '
      '(even with non-zero fatigueScore and non-null lastSetTimestamp)',
      () async {
        const targetMuscle = stimulus_constants.MuscleStimulus.triceps;
        stubOtherMuscles(targetMuscle);

        when(
          () => repository.getStimulusByMuscleAndDate(
            muscleGroup: targetMuscle,
            date: todayStart,
          ),
        ).thenAnswer(
          (_) async => Right(
            stimulus_entity.MuscleStimulus(
              id: 'triceps-today',
              ownerUserId: testUserId,
              muscleGroup: targetMuscle,
              date: todayStart,
              dailyStimulus: 0.0,
              rollingWeeklyLoad: 0.0,
              lastSetTimestamp: todayStart.millisecondsSinceEpoch,
              fatigueAnchorTimestamp: null,
              fatigueScore: 40.0,
              createdAt: todayStart,
              updatedAt: todayStart,
            ),
          ),
        );

        final result = await usecaseWithClock(TimePeriod.week);
        final data = result.getOrElse(() => throw StateError('expected data'));

        // fatigueAnchorTimestamp == null → no accumulated fatigue → untrained
        expect(data[targetMuscle]!.hasTrained, isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // All-time: relative total-volume ranking
  // ---------------------------------------------------------------------------
  //
  // Scenario: quads has 10 000 total volume (the maximum), chest has
  // 2 000, and every other muscle has 0.  Expected outcome:
  //   quads  → maximum bucket (ratio 1.0 → red)
  //   chest  → some trained bucket (ratio 0.2 → green)
  //   others → untrained (gray)

  group('All-time relative total-volume ranking', () {
    setUp(() {
      for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        double volume = 0.0;
        if (m == stimulus_constants.MuscleStimulus.quads) volume = 10000.0;
        if (m == stimulus_constants.MuscleStimulus.chest) volume = 2000.0;

        when(
          () => repository.getTotalVolumeForMuscle(
            m,
            startDate: null,
            endDate: null,
          ),
        ).thenAnswer((_) async => Right(volume));
      }
    });

    test('most-trained muscle (quads) reaches maximum bucket', () async {
      final result = await usecase(TimePeriod.allTime);
      final data = result.getOrElse(() => throw StateError('expected data'));

      expect(
        data[stimulus_constants.MuscleStimulus.quads]!.bucket,
        MuscleVisualBucket.maximum,
        reason: 'the muscle with the highest total volume must be maximum/red',
      );
      expect(data[stimulus_constants.MuscleStimulus.quads]!.hasTrained, isTrue);
    });

    test(
      'lightly-trained muscle (chest, 20 % of max) is trained/green',
      () async {
        final result = await usecase(TimePeriod.allTime);
        final data = result.getOrElse(() => throw StateError('expected data'));

        final chest = data[stimulus_constants.MuscleStimulus.chest]!;
        expect(
          chest.hasTrained,
          isTrue,
          reason: 'a muscle with non-zero total volume must be trained',
        );
        // ratio 0.2 → below orange threshold → green or low bucket
        expect(
          chest.bucket,
          isNot(MuscleVisualBucket.maximum),
          reason: '20 %% of max must not be the maximum bucket',
        );
      },
    );

    test('untrained muscles render as untrained (gray)', () async {
      final result = await usecase(TimePeriod.allTime);
      final data = result.getOrElse(() => throw StateError('expected data'));

      final untrainedMuscles = stimulus_constants.MuscleStimulus.allMuscleGroups
          .where(
            (m) =>
                m != stimulus_constants.MuscleStimulus.quads &&
                m != stimulus_constants.MuscleStimulus.chest,
          )
          .toList();

      for (final m in untrainedMuscles) {
        expect(
          data[m]!.hasTrained,
          isFalse,
          reason: '$m has 0 volume and must render as untrained',
        );
      }
    });

    test(
      'all-untrained (zero volume across all muscles) → all untrained',
      () async {
        // Override all muscles to zero
        for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
          when(
            () => repository.getTotalVolumeForMuscle(
              m,
              startDate: null,
              endDate: null,
            ),
          ).thenAnswer((_) async => const Right(0.0));
        }

        final result = await usecase(TimePeriod.allTime);
        final data = result.getOrElse(() => throw StateError('expected data'));

        expect(
          data.values.every((d) => !d.hasTrained),
          isTrue,
          reason:
              'with no workout history, every muscle must be untrained/gray',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Month: current calendar month, relative total-volume ranking
  // ---------------------------------------------------------------------------
  //
  // Fixed clock: 2026-06-15. Month window: [2026-06-01, 2026-06-15] inclusive.
  // Scenario: quads has 8 000 in-month volume (maximum), lats has 1 600 (20 %),
  // all others 0.

  group('Month relative total-volume ranking', () {
    // Fixed clock for deterministic calendar-month boundaries.
    final fixedNow = DateTime(2026, 6, 15);
    final monthStart = DateTime(2026, 6, 1);
    final todayStart = DateTime(2026, 6, 15);

    late GetMuscleVisualData usecaseWithClock;

    setUp(() {
      usecaseWithClock = GetMuscleVisualData(
        repository,
        clock: FakeClock(fixedNow),
      );

      for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        double volume = 0.0;
        if (m == stimulus_constants.MuscleStimulus.quads) volume = 8000.0;
        if (m == stimulus_constants.MuscleStimulus.lats) volume = 1600.0;

        when(
          () => repository.getTotalVolumeForMuscle(
            m,
            startDate: monthStart,
            endDate: todayStart,
          ),
        ).thenAnswer((_) async => Right(volume));
      }
    });

    test('most-trained muscle (quads) reaches maximum bucket', () async {
      final result = await usecaseWithClock(TimePeriod.month);
      final data = result.getOrElse(() => throw StateError('expected data'));

      expect(
        data[stimulus_constants.MuscleStimulus.quads]!.bucket,
        MuscleVisualBucket.maximum,
        reason: 'highest in-month volume must be maximum/red',
      );
      expect(data[stimulus_constants.MuscleStimulus.quads]!.hasTrained, isTrue);
    });

    test(
      'lightly-trained muscle (lats, 20 % of max) is trained and not maximum',
      () async {
        final result = await usecaseWithClock(TimePeriod.month);
        final data = result.getOrElse(() => throw StateError('expected data'));

        final lats = data[stimulus_constants.MuscleStimulus.lats]!;
        expect(lats.hasTrained, isTrue);
        expect(
          lats.bucket,
          isNot(MuscleVisualBucket.maximum),
          reason: '20 %% of max must not be the maximum bucket',
        );
      },
    );

    test('untrained muscles render as untrained (gray)', () async {
      final result = await usecaseWithClock(TimePeriod.month);
      final data = result.getOrElse(() => throw StateError('expected data'));

      final untrainedMuscles = stimulus_constants.MuscleStimulus.allMuscleGroups
          .where(
            (m) =>
                m != stimulus_constants.MuscleStimulus.quads &&
                m != stimulus_constants.MuscleStimulus.lats,
          )
          .toList();

      for (final m in untrainedMuscles) {
        expect(
          data[m]!.hasTrained,
          isFalse,
          reason: '$m has 0 in-month volume and must render as untrained',
        );
      }
    });

    test(
      'window bounds are [firstOfMonth, today] — repository called with correct dates',
      () async {
        await usecaseWithClock(TimePeriod.month);

        // Verify every muscle was queried with the calendar-month window, not
        // trailing-30-day or any other window.
        for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
          verify(
            () => repository.getTotalVolumeForMuscle(
              m,
              startDate: monthStart,
              endDate: todayStart,
            ),
          ).called(1);
        }
      },
    );

    test('all-zero month → all muscles untrained', () async {
      // Override to zero for all
      for (final m in stimulus_constants.MuscleStimulus.allMuscleGroups) {
        when(
          () => repository.getTotalVolumeForMuscle(
            m,
            startDate: monthStart,
            endDate: todayStart,
          ),
        ).thenAnswer((_) async => const Right(0.0));
      }

      final result = await usecaseWithClock(TimePeriod.month);
      final data = result.getOrElse(() => throw StateError('expected data'));

      expect(
        data.values.every((d) => !d.hasTrained),
        isTrue,
        reason: 'no in-month sets → every muscle untrained/gray',
      );
    });
  });
}
