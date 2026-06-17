import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart'
    as stimulus_constants;
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/utils/calendar_day.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:fitness_tracker/domain/entities/stimulus_calculation_rules.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/repositories/muscle_stimulus_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../integration/support/fake_clock.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockMuscleStimulusRepository extends Mock
    implements MuscleStimulusRepository {}

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

void main() {
  late MockWorkoutSetRepository workoutSetRepository;
  late MockMuscleStimulusRepository muscleStimulusRepository;
  late MockMuscleFactorRepository muscleFactorRepository;
  late RebuildMuscleStimulusFromWorkoutHistory usecase;
  late List<MuscleStimulus> upsertedRecords;

  const String testUserId = 'user-1';

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final twoDaysAgo = todayStart.subtract(const Duration(days: 2));

  setUpAll(() {
    registerFallbackValue(
      MuscleStimulus(
        id: 'fallback',
        ownerUserId: testUserId,
        muscleGroup: stimulus_constants.MuscleStimulus.midChest,
        date: DateTime(2026, 1, 1),
        dailyStimulus: 0,
        rollingWeeklyLoad: 0,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    workoutSetRepository = MockWorkoutSetRepository();
    muscleStimulusRepository = MockMuscleStimulusRepository();
    muscleFactorRepository = MockMuscleFactorRepository();
    upsertedRecords = <MuscleStimulus>[];

    usecase = RebuildMuscleStimulusFromWorkoutHistory(
      workoutSetRepository: workoutSetRepository,
      muscleStimulusRepository: muscleStimulusRepository,
      calculateMuscleStimulus: CalculateMuscleStimulus(
        muscleFactorRepository: muscleFactorRepository,
      ),
    );

    when(
      () => muscleStimulusRepository.clearStimulusForUser(testUserId),
    ).thenAnswer((_) async => const Right(null));

    when(() => muscleStimulusRepository.upsertStimulus(any())).thenAnswer((
      invocation,
    ) async {
      upsertedRecords.add(
        invocation.positionalArguments.first as MuscleStimulus,
      );
      return const Right(null);
    });

    when(
      () => workoutSetRepository.getAllSets(
        sourcePreference: DataSourcePreference.localOnly,
      ),
    ).thenAnswer(
      (_) async => Right(<WorkoutSet>[
        WorkoutSet(
          id: 'bench-1',
          exerciseId: 'bench',
          reps: 8,
          weight: 80,
          intensity: 4,
          date: todayStart.add(const Duration(hours: 9)),
          createdAt: todayStart.add(const Duration(hours: 9)),
        ),
        WorkoutSet(
          id: 'bench-2',
          exerciseId: 'bench',
          reps: 6,
          weight: 85,
          intensity: 5,
          date: todayStart.add(const Duration(hours: 9, minutes: 10)),
          createdAt: todayStart.add(const Duration(hours: 9, minutes: 10)),
        ),
        WorkoutSet(
          id: 'squat-1',
          exerciseId: 'squat',
          reps: 5,
          weight: 110,
          intensity: 5,
          date: twoDaysAgo.add(const Duration(hours: 18)),
          createdAt: twoDaysAgo.add(const Duration(hours: 18)),
        ),
      ]),
    );

    when(
      () => muscleFactorRepository.getFactorsForExercise('bench'),
    ).thenAnswer(
      (_) async => const Right(<MuscleFactor>[
        MuscleFactor(
          id: 'bench-chest',
          exerciseId: 'bench',
          muscleGroup: 'mid-chest',
          factor: 0.9,
        ),
        MuscleFactor(
          id: 'bench-triceps',
          exerciseId: 'bench',
          muscleGroup: 'triceps',
          factor: 0.55,
        ),
      ]),
    );

    when(
      () => muscleFactorRepository.getFactorsForExercise('squat'),
    ).thenAnswer(
      (_) async => const Right(<MuscleFactor>[
        MuscleFactor(
          id: 'squat-quads',
          exerciseId: 'squat',
          muscleGroup: 'quads',
          factor: 0.9,
        ),
      ]),
    );
  });

  test(
    'rebuild clears stale today muscles while preserving historic load',
    () async {
      final result = await usecase(testUserId);

      expect(result.isRight(), isTrue);
      // Must call the user-scoped clear, never the global clear
      verify(
        () => muscleStimulusRepository.clearStimulusForUser(testUserId),
      ).called(1);
      verifyNever(() => muscleStimulusRepository.clearAllStimulus());

      final todayQuads = upsertedRecords.firstWhere(
        (record) =>
            record.muscleGroup == stimulus_constants.MuscleStimulus.quads &&
            record.date == todayStart,
      );
      final todayChest = upsertedRecords.firstWhere(
        (record) =>
            record.muscleGroup == stimulus_constants.MuscleStimulus.midChest &&
            record.date == todayStart,
      );

      expect(todayQuads.dailyStimulus, 0);
      expect(todayQuads.rollingWeeklyLoad, greaterThan(0));
      expect(todayChest.dailyStimulus, greaterThan(0));
    },
  );

  test('rebuilt records are stamped with the provided userId', () async {
    await usecase(testUserId);

    expect(
      upsertedRecords.every((r) => r.ownerUserId == testUserId),
      isTrue,
      reason: 'every rebuilt record must carry the correct ownerUserId',
    );
  });

  test('does not touch clearStimulusForUser for a different userId', () async {
    const otherUserId = 'user-other';
    when(
      () => muscleStimulusRepository.clearStimulusForUser(otherUserId),
    ).thenAnswer((_) async => const Right(null));

    await usecase(testUserId);

    verifyNever(
      () => muscleStimulusRepository.clearStimulusForUser(otherUserId),
    );
  });

  // -------------------------------------------------------------------------
  // Invariant tests: pin the correctness property introduced by the DST fix.
  //
  // These tests use a FakeClock so "today" is deterministic and independent of
  // wall-clock drift.  On UTC CI the DST manifestation cannot be reproduced
  // (no spring-forward in UTC), but the invariants below prove that the
  // component-based iteration always produces non-zero records on workout days.
  // See KNOWN_ISSUES.md #muscle-stimulus-rebuild-dst-day-iteration.
  // -------------------------------------------------------------------------

  group('DST-safe rebuild invariants', () {
    // Fixed "today" anchor used by every test in this group.
    final fixedToday = DateTime(2026, 6, 3, 12, 0); // 2026-06-03 noon

    /// Wire up a fresh usecase with a FakeClock frozen at [fixedToday].
    RebuildMuscleStimulusFromWorkoutHistory _usecaseWith(
      List<WorkoutSet> sets,
    ) {
      when(
        () => workoutSetRepository.getAllSets(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right(sets));

      return RebuildMuscleStimulusFromWorkoutHistory(
        workoutSetRepository: workoutSetRepository,
        muscleStimulusRepository: muscleStimulusRepository,
        calculateMuscleStimulus: CalculateMuscleStimulus(
          muscleFactorRepository: muscleFactorRepository,
        ),
        clock: FakeClock(fixedToday),
      );
    }

    test('a set dated today produces a today record with dailyStimulus > 0 '
        'and a non-null lastSetTimestamp', () async {
      final todayMidnight = CalendarDay.startOfDay(fixedToday);

      final uc = _usecaseWith([
        WorkoutSet(
          id: 'bench-today',
          exerciseId: 'bench',
          reps: 8,
          weight: 80,
          intensity: 4,
          date: todayMidnight.add(const Duration(hours: 9)),
          createdAt: todayMidnight.add(const Duration(hours: 9)),
        ),
      ]);

      upsertedRecords.clear();
      final result = await uc(testUserId);

      expect(result.isRight(), isTrue);

      final todayRecord = upsertedRecords.firstWhere(
        (r) =>
            r.date == todayMidnight &&
            r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
      );

      expect(
        todayRecord.dailyStimulus,
        greaterThan(0),
        reason:
            'a set logged today must produce dailyStimulus > 0 on today\'s record',
      );
      expect(
        todayRecord.lastSetTimestamp,
        isNotNull,
        reason:
            'a set logged today must populate lastSetTimestamp on today\'s record',
      );
    });

    test(
      'a past set and a today set both yield non-zero dailyStimulus; '
      'gap days have zero dailyStimulus; '
      'total distinct dates == calendarDaysBetween(earliest, today) + 1',
      () async {
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        // Place a past set 5 calendar days before today.
        final pastDay = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 5,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'squat-past',
            exerciseId: 'squat',
            reps: 5,
            weight: 110,
            intensity: 5,
            date: pastDay.add(const Duration(hours: 18)),
            createdAt: pastDay.add(const Duration(hours: 18)),
          ),
          WorkoutSet(
            id: 'bench-today',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: todayMidnight.add(const Duration(hours: 9)),
            createdAt: todayMidnight.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        final result = await uc(testUserId);

        expect(result.isRight(), isTrue);

        // The past day's set must have non-zero stimulus.
        final pastRecords = upsertedRecords.where((r) => r.date == pastDay);
        expect(pastRecords, isNotEmpty);
        expect(
          pastRecords.any((r) => r.dailyStimulus > 0),
          isTrue,
          reason:
              'the past workout day must have at least one muscle with '
              'dailyStimulus > 0',
        );

        // Today's set must have non-zero stimulus.
        final todayChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == todayMidnight &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          todayChest.dailyStimulus,
          greaterThan(0),
          reason: 'today\'s chest record must have dailyStimulus > 0',
        );

        // Gap days (days between past and today that have no workout) must
        // exist in the output (carry-forward rows) with dailyStimulus == 0.
        final gapDays = upsertedRecords
            .where(
              (r) => r.date.isAfter(pastDay) && r.date.isBefore(todayMidnight),
            )
            .map((r) => r.date)
            .toSet();
        // There are 4 gap days between day-5 and today (exclusive on both ends).
        expect(
          gapDays.length,
          4,
          reason: 'carry-forward rows must exist for all 4 gap days',
        );
        for (final gapDate in gapDays) {
          final gapRecords = upsertedRecords
              .where((r) => r.date == gapDate)
              .toList();
          expect(
            gapRecords.every((r) => r.dailyStimulus == 0),
            isTrue,
            reason:
                'gap-day $gapDate must have dailyStimulus == 0 '
                '(carry-forward row only)',
          );
        }

        // Total distinct calendar dates == calendarDaysBetween(earliest, today) + 1
        final distinctDates = upsertedRecords.map((r) => r.date).toSet();
        final expectedDateCount =
            CalendarDay.calendarDaysBetween(pastDay, todayMidnight) + 1;
        expect(
          distinctDates.length,
          expectedDateCount,
          reason:
              'rebuild must emit exactly one set of records per calendar '
              'day from earliest to today (inclusive)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // fatigueScore correctness
    // -------------------------------------------------------------------------

    test(
      'single set today: fatigueScore == fatigueGain(weight,reps,intensity,factor)',
      () async {
        // bench: weight=80, reps=8, intensity=4
        // mid-chest factor = 0.9
        // multiplier(4) = 1 + ((4-1)/4)^2 = 1 + (0.75)^2 = 1.5625
        // gain = 80*8 * 1.5625 * 0.9 / 250 = 640 * 1.5625 * 0.9 / 250
        //      = 900 / 250 = 3.6
        final todayMidnight = CalendarDay.startOfDay(fixedToday);

        final expectedGain = StimulusCalculationRules.fatigueGain(
          weight: 80.0,
          reps: 8,
          intensity: 4,
          muscleFactor: 0.9,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bench-today',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: todayMidnight.add(const Duration(hours: 9)),
            createdAt: todayMidnight.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        final result = await uc(testUserId);
        expect(result.isRight(), isTrue);

        final todayChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == todayMidnight &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          todayChest.fatigueScore,
          closeTo(expectedGain, 1e-9),
          reason: 'single set: fatigueScore must equal the raw gain',
        );
      },
    );

    test('two sets on same day: gains sum then cap at 100', () async {
      // Use very heavy sets to force cap.
      // weight=1000, reps=100, intensity=5, factor=0.9
      // multiplier(5)=2.0; gain = 1000*100 * 2.0 * 0.9 / 250 = 720
      // Two such sets → 720+720=1440, capped at 100.
      final todayMidnight = CalendarDay.startOfDay(fixedToday);

      // Override bench factors to use factor=0.9 only for mid-chest
      when(
        () => muscleFactorRepository.getFactorsForExercise('heavy'),
      ).thenAnswer(
        (_) async => const Right(<MuscleFactor>[
          MuscleFactor(
            id: 'heavy-chest',
            exerciseId: 'heavy',
            muscleGroup: 'mid-chest',
            factor: 0.9,
          ),
        ]),
      );

      final uc = _usecaseWith([
        WorkoutSet(
          id: 'h1',
          exerciseId: 'heavy',
          reps: 100,
          weight: 1000,
          intensity: 5,
          date: todayMidnight.add(const Duration(hours: 9)),
          createdAt: todayMidnight.add(const Duration(hours: 9)),
        ),
        WorkoutSet(
          id: 'h2',
          exerciseId: 'heavy',
          reps: 100,
          weight: 1000,
          intensity: 5,
          date: todayMidnight.add(const Duration(hours: 10)),
          createdAt: todayMidnight.add(const Duration(hours: 10)),
        ),
      ]);

      upsertedRecords.clear();
      await uc(testUserId);

      final todayChest = upsertedRecords.firstWhere(
        (r) =>
            r.date == todayMidnight &&
            r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
      );
      expect(
        todayChest.fatigueScore,
        closeTo(100.0, 1e-9),
        reason: 'combined gain > 100 must cap at 100',
      );
    });

    test(
      'set on day A then day A+3: day A+3 fatigueScore == accumulate(decay(A, 3), gainA3)',
      () async {
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        final dayA = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 3,
        );

        // bench: weight=80, reps=8, intensity=4, mid-chest factor=0.9
        final gainA = StimulusCalculationRules.fatigueGain(
          weight: 80.0,
          reps: 8,
          intensity: 4,
          muscleFactor: 0.9,
        );
        // After 3 days of decay from dayA to today (dayA+3):
        final decayedA = StimulusCalculationRules.decayFatigue(gainA, 3);
        // Today's set adds the same gain again:
        final expectedToday = StimulusCalculationRules.accumulateFatigue(
          decayedA,
          gainA,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bench-dayA',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: dayA.add(const Duration(hours: 9)),
            createdAt: dayA.add(const Duration(hours: 9)),
          ),
          WorkoutSet(
            id: 'bench-today',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: todayMidnight.add(const Duration(hours: 9)),
            createdAt: todayMidnight.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        final result = await uc(testUserId);
        expect(result.isRight(), isTrue);

        final dayAChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == dayA &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          dayAChest.fatigueScore,
          closeTo(gainA, 1e-9),
          reason: 'day A must store the raw at-last-set gain',
        );

        final todayChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == todayMidnight &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          todayChest.fatigueScore,
          closeTo(expectedToday, 1e-9),
          reason: 'decay(A,3) then accumulate must match expected value',
        );
      },
    );

    test(
      'carry-forward (gap) days store the at-last-set fatigueScore unchanged',
      () async {
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        final pastDay = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 2,
        );

        final gain = StimulusCalculationRules.fatigueGain(
          weight: 80.0,
          reps: 8,
          intensity: 4,
          muscleFactor: 0.9,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bench-past',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: pastDay.add(const Duration(hours: 9)),
            createdAt: pastDay.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        await uc(testUserId);

        final gapDay = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 1,
        );
        final gapChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == gapDay &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        // Gap day stores the at-last-set value (no decay applied here).
        expect(
          gapChest.fatigueScore,
          closeTo(gain, 1e-9),
          reason: 'carry-forward day must carry the at-last-set fatigueScore',
        );
      },
    );

    test(
      'dailyStimulus and dailyVolume outputs unchanged by fatigue addition',
      () async {
        // Verify the refactor has not altered existing outputs.
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        final pastDay = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 2,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bench-past',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: pastDay.add(const Duration(hours: 9)),
            createdAt: pastDay.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        await uc(testUserId);

        final pastChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == pastDay &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          pastChest.dailyVolume,
          closeTo(756.0, 0.001), // effectiveLoad(80)=105 → 105*8*0.9
          reason: 'dailyVolume must be unaffected by fatigue addition',
        );
        expect(
          pastChest.dailyStimulus,
          greaterThan(0),
          reason: 'dailyStimulus must be unaffected by fatigue addition',
        );
      },
    );

    // -------------------------------------------------------------------------
    // fatigueAnchorTimestamp correctness (Plan-1 regression)
    // -------------------------------------------------------------------------

    test(
      'weighted set day A then bodyweight set day A+N: anchor advances to A+N '
      '(bodyweight now accumulates fatigue), lastSetTimestamp advances to A+N',
      () async {
        // Post-A3 the bodyweight floor makes weight==0 sets accumulate gain > 0,
        // so the anchor — the last day fatigue actually grew — must advance to
        // the bodyweight day too (the old behaviour left it stuck at dayA).
        // bench (weight=80): gain > 0 on dayA.
        // bodyweight-push (weight=0): gain > 0 on dayA+4 via the rep-load floor.
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        final dayA = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 4,
        );
        final dayAplus4 = todayMidnight; // "today"

        when(
          () => muscleFactorRepository.getFactorsForExercise('bw-push'),
        ).thenAnswer(
          (_) async => const Right(<MuscleFactor>[
            MuscleFactor(
              id: 'bw-chest',
              exerciseId: 'bw-push',
              muscleGroup: 'mid-chest',
              factor: 0.9,
            ),
          ]),
        );

        final uc = _usecaseWith([
          // Weighted set on dayA
          WorkoutSet(
            id: 'bench-dayA',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: dayA.add(const Duration(hours: 9)),
            createdAt: dayA.add(const Duration(hours: 9)),
          ),
          // Bodyweight set on dayA+4 (weight == 0 → fatigueGain > 0 post-A3)
          WorkoutSet(
            id: 'bw-push-today',
            exerciseId: 'bw-push',
            reps: 20,
            weight: 0,
            intensity: 3,
            date: dayAplus4.add(const Duration(hours: 10)),
            createdAt: dayAplus4.add(const Duration(hours: 10)),
          ),
        ]);

        upsertedRecords.clear();
        final result = await uc(testUserId);
        expect(result.isRight(), isTrue);

        final todayChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == dayAplus4 &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );

        // Anchor advances to dayA+4 — the bodyweight set now grows fatigue.
        expect(
          todayChest.fatigueAnchorTimestamp,
          dayAplus4.millisecondsSinceEpoch,
          reason:
              'fatigueAnchorTimestamp must advance to the bodyweight day — '
              'post-A3 a weight==0 set has gain > 0',
        );
        // lastSetTimestamp must advance to dayA+4 (any set advances it).
        expect(
          todayChest.lastSetTimestamp,
          isNotNull,
          reason: 'lastSetTimestamp must be set (any set advances it)',
        );
        expect(
          todayChest.lastSetTimestamp! >=
              dayAplus4.add(const Duration(hours: 10)).millisecondsSinceEpoch,
          isTrue,
          reason:
              'lastSetTimestamp must be at or after the bodyweight set time',
        );
      },
    );

    test(
      'weighted-only muscle: fatigueAnchorTimestamp == startOfDay(lastSetDate)',
      () async {
        final todayMidnight = CalendarDay.startOfDay(fixedToday);
        final pastDay = DateTime(
          todayMidnight.year,
          todayMidnight.month,
          todayMidnight.day - 1,
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bench-past',
            exerciseId: 'bench',
            reps: 8,
            weight: 80,
            intensity: 4,
            date: pastDay.add(const Duration(hours: 9)),
            createdAt: pastDay.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        await uc(testUserId);

        final pastChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == pastDay &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        expect(
          pastChest.fatigueAnchorTimestamp,
          pastDay.millisecondsSinceEpoch,
          reason: 'for weighted-only muscle, anchor == midnight of the set day',
        );
      },
    );

    test(
      'bodyweight-only muscle: fatigueScore > 0 and fatigueAnchorTimestamp set',
      () async {
        // weight=0 throughout → post-A3 fatigueGain > 0 via the rep-load floor,
        // so the muscle accumulates fatigue and the anchor is set to the set day.
        final todayMidnight = CalendarDay.startOfDay(fixedToday);

        when(
          () => muscleFactorRepository.getFactorsForExercise('bw-only'),
        ).thenAnswer(
          (_) async => const Right(<MuscleFactor>[
            MuscleFactor(
              id: 'bw-only-chest',
              exerciseId: 'bw-only',
              muscleGroup: 'mid-chest',
              factor: 0.9,
            ),
          ]),
        );

        final uc = _usecaseWith([
          WorkoutSet(
            id: 'bw-set',
            exerciseId: 'bw-only',
            reps: 20,
            weight: 0,
            intensity: 3,
            date: todayMidnight.add(const Duration(hours: 9)),
            createdAt: todayMidnight.add(const Duration(hours: 9)),
          ),
        ]);

        upsertedRecords.clear();
        await uc(testUserId);

        final todayChest = upsertedRecords.firstWhere(
          (r) =>
              r.date == todayMidnight &&
              r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
        );
        // effectiveLoad(0)=25 → gain = (25*20)*1.25*0.9/250 = 2.25
        final expectedGain = StimulusCalculationRules.fatigueGain(
          weight: 0.0,
          reps: 20,
          intensity: 3,
          muscleFactor: 0.9,
        );
        expect(expectedGain, greaterThan(0.0));
        expect(
          todayChest.fatigueScore,
          closeTo(expectedGain, 1e-9),
          reason: 'bodyweight-only: fatigueScore must equal the rep-floor gain',
        );
        expect(
          todayChest.fatigueAnchorTimestamp,
          todayMidnight.millisecondsSinceEpoch,
          reason: 'bodyweight-only: anchor must be set to the set day',
        );
      },
    );

    // -------------------------------------------------------------------------
    // daily_volume correctness
    // -------------------------------------------------------------------------

    test('workout-day record has dailyVolume == effectiveLoad*reps*factor; '
        'carry-forward days have dailyVolume == 0.0; '
        'dailyStimulus is unchanged by the refactor', () async {
      // bench: weight=80 → effectiveLoad=105, reps=8, intensity=4
      //   factor(mid-chest)  = 0.9  → volume contribution = 105*8*0.9 = 756.0
      //   factor(triceps)    = 0.55 → volume contribution = 105*8*0.55 = 462.0
      //
      // dailyStimulus for mid-chest (intensity=4, factor=0.9):
      //   calculateSetStimulus(sets:1, intensity:4, exerciseFactor:0.9)
      //   = 1 * pow(1.2, 3) * 0.9 = 1.728 * 0.9 ≈ 1.5552  (checked via real formula)
      final todayMidnight = CalendarDay.startOfDay(fixedToday);
      final pastDay = DateTime(
        todayMidnight.year,
        todayMidnight.month,
        todayMidnight.day - 2,
      );

      final uc = _usecaseWith([
        WorkoutSet(
          id: 'bench-past',
          exerciseId: 'bench',
          reps: 8,
          weight: 80,
          intensity: 4,
          date: pastDay.add(const Duration(hours: 9)),
          createdAt: pastDay.add(const Duration(hours: 9)),
        ),
      ]);

      upsertedRecords.clear();
      final result = await uc(testUserId);
      expect(result.isRight(), isTrue);

      // Workout-day records
      final pastChest = upsertedRecords.firstWhere(
        (r) =>
            r.date == pastDay &&
            r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
      );
      final pastTriceps = upsertedRecords.firstWhere(
        (r) =>
            r.date == pastDay &&
            r.muscleGroup == stimulus_constants.MuscleStimulus.triceps,
      );

      expect(
        pastChest.dailyVolume,
        closeTo(756.0, 0.001), // 105 * 8 * 0.9 (effectiveLoad=80+25)
        reason: 'mid-chest daily_volume = effectiveLoad*reps*factor',
      );
      expect(
        pastTriceps.dailyVolume,
        closeTo(462.0, 0.001), // 105 * 8 * 0.55 (effectiveLoad=80+25)
        reason: 'triceps daily_volume = effectiveLoad*reps*factor',
      );

      // Stimulus is unchanged — same math as the old calculateForSet path.
      expect(
        pastChest.dailyStimulus,
        greaterThan(0),
        reason: 'dailyStimulus must be non-zero (refactor must not change it)',
      );

      // Carry-forward rows (today, no workout) must have dailyVolume = 0.0.
      final todayChest = upsertedRecords.firstWhere(
        (r) =>
            r.date == todayMidnight &&
            r.muscleGroup == stimulus_constants.MuscleStimulus.midChest,
      );
      expect(
        todayChest.dailyVolume,
        closeTo(0.0, 0.001),
        reason: 'carry-forward day must have dailyVolume = 0.0',
      );
    });
  });
}
