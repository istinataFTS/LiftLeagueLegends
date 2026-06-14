import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/add_workout_set.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_exercise_personal_record.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_weekly_sets.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddWorkoutSet extends Mock implements AddWorkoutSet {}

class MockGetWeeklySets extends Mock implements GetWeeklySets {}

class MockCalculateMuscleStimulus extends Mock
    implements CalculateMuscleStimulus {}

class MockGetMuscleVisualData extends Mock implements GetMuscleVisualData {}

class MockGetExercisePersonalRecord extends Mock
    implements GetExercisePersonalRecord {}

void main() {
  setUpAll(() {
    registerFallbackValue(TimePeriod.week);
  });

  late MockAddWorkoutSet mockAddWorkoutSet;
  late MockGetWeeklySets mockGetWeeklySets;
  late MockCalculateMuscleStimulus mockCalculateMuscleStimulus;
  late MockGetMuscleVisualData mockGetMuscleVisualData;
  late MockGetExercisePersonalRecord mockGetExercisePersonalRecord;
  late WorkoutBloc bloc;

  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day, 12);

  final workoutSet = WorkoutSet(
    id: 'set-1',
    exerciseId: 'exercise-1',
    reps: 10,
    weight: 80,
    intensity: 3,
    date: todayMidnight,
    createdAt: todayMidnight,
  );

  final weeklySets = [workoutSet, workoutSet.copyWith(id: 'set-2', reps: 8)];

  final exercise = Exercise(
    id: 'exercise-1',
    name: 'Bench Press',
    muscleGroups: const ['chest', 'triceps'],
    createdAt: DateTime(2026, 1, 1),
  );

  final personalRecordSet = WorkoutSet(
    id: 'pr-set',
    exerciseId: 'exercise-1',
    reps: 5,
    weight: 105,
    intensity: 4,
    date: DateTime(2025, 12, 1),
    createdAt: DateTime(2025, 12, 1),
  );

  MuscleVisualData visual({
    required String muscle,
    required double intensity,
    MuscleVisualBucket bucket = MuscleVisualBucket.moderate,
  }) {
    return MuscleVisualData(
      muscleGroup: muscle,
      totalStimulus: intensity,
      threshold: 1.0,
      visualIntensity: intensity,
      bucket: bucket,
      coverageState: MuscleVisualCoverageState.partial,
      aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      visibleSurfaces: const <MuscleVisualSurface>{MuscleVisualSurface.front},
      overflowAmount: 0,
      hasTrained: true,
    );
  }

  setUp(() {
    mockAddWorkoutSet = MockAddWorkoutSet();
    mockGetWeeklySets = MockGetWeeklySets();
    mockCalculateMuscleStimulus = MockCalculateMuscleStimulus();
    mockGetMuscleVisualData = MockGetMuscleVisualData();
    mockGetExercisePersonalRecord = MockGetExercisePersonalRecord();

    // Default stubs so legacy tests that don't care about the new deps still
    // run without throwing.
    when(
      () => mockGetExercisePersonalRecord(any()),
    ).thenAnswer((_) async => const Right<Failure, WorkoutSet?>(null));
    when(() => mockGetMuscleVisualData(any())).thenAnswer(
      (_) async => const Right<Failure, Map<String, MuscleVisualData>>(
        <String, MuscleVisualData>{},
      ),
    );

    bloc = WorkoutBloc(
      addWorkoutSet: mockAddWorkoutSet,
      getWeeklySets: mockGetWeeklySets,
      calculateMuscleStimulus: mockCalculateMuscleStimulus,
      getMuscleVisualData: mockGetMuscleVisualData,
      getExercisePersonalRecord: mockGetExercisePersonalRecord,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('WorkoutBloc', () {
    late Future<WorkoutUiEffect> _addSetEffectFuture;

    blocTest<WorkoutBloc, WorkoutState>(
      'emits loading then loaded when weekly sets load succeeds',
      build: () {
        when(
          () => mockGetWeeklySets(),
        ).thenAnswer((_) async => Right(weeklySets));
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadWeeklySetsEvent()),
      expect: () => [isA<WorkoutLoading>(), WorkoutLoaded(weeklySets)],
      verify: (_) {
        expect(bloc.cachedWeeklySets, weeklySets);
      },
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'emits error when weekly sets load fails',
      build: () {
        when(() => mockGetWeeklySets()).thenAnswer(
          (_) async =>
              const Left(DatabaseFailure('Failed to load weekly sets')),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(const LoadWeeklySetsEvent()),
      expect: () => [
        isA<WorkoutLoading>(),
        const WorkoutError('Failed to load weekly sets'),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'emits loading then loaded when add workout set succeeds',
      build: () {
        when(
          () => mockAddWorkoutSet(workoutSet),
        ).thenAnswer((_) async => const Right(null));

        when(
          () => mockCalculateMuscleStimulus.calculateForSet(
            exerciseId: workoutSet.exerciseId,
            sets: 1,
            intensity: workoutSet.intensity,
          ),
        ).thenAnswer((_) async => const Right({'chest': 5.0, 'triceps': 3.0}));

        when(
          () => mockGetWeeklySets(),
        ).thenAnswer((_) async => Right(weeklySets));

        _addSetEffectFuture = bloc.effects.first;
        return bloc;
      },
      act: (bloc) => bloc.add(AddWorkoutSetEvent(workoutSet)),
      expect: () => [isA<WorkoutLoading>(), WorkoutLoaded(weeklySets)],
      verify: (_) async {
        expect(bloc.cachedWeeklySets, weeklySets);

        final effect = await _addSetEffectFuture;
        expect(effect, isA<WorkoutLoggedEffect>());

        final loggedEffect = effect as WorkoutLoggedEffect;
        expect(loggedEffect.message, AppStrings.setLogged);
        expect(loggedEffect.affectedMuscles, containsAll(['chest', 'triceps']));
      },
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'emits error when add workout set fails',
      build: () {
        when(() => mockAddWorkoutSet(workoutSet)).thenAnswer(
          (_) async => const Left(DatabaseFailure('Failed to save set')),
        );
        return bloc;
      },
      act: (bloc) => bloc.add(AddWorkoutSetEvent(workoutSet)),
      expect: () => [
        isA<WorkoutLoading>(),
        const WorkoutError('Failed to save set'),
      ],
      verify: (_) {
        verifyNever(() => mockGetWeeklySets());
      },
    );

    test(
      'emits WorkoutMutationFailedEffect alongside WorkoutError on failure',
      () async {
        when(() => mockAddWorkoutSet(workoutSet)).thenAnswer(
          (_) async => const Left(DatabaseFailure('db write failed')),
        );

        final effectFuture = bloc.effects.first;
        bloc.add(AddWorkoutSetEvent(workoutSet));

        final effect = await effectFuture;
        expect(effect, isA<WorkoutMutationFailedEffect>());
        expect(
          (effect as WorkoutMutationFailedEffect).message,
          'db write failed',
        );
        expect(bloc.state, const WorkoutError('db write failed'));
      },
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'refresh emits loaded without forcing loading state',
      build: () {
        when(
          () => mockGetWeeklySets(),
        ).thenAnswer((_) async => Right(weeklySets));
        return bloc;
      },
      act: (bloc) => bloc.add(const RefreshWeeklySetsEvent()),
      expect: () => [WorkoutLoaded(weeklySets)],
    );

    test(
      'select exercise emits WorkoutLoaded with populated insight',
      () async {
        when(() => mockGetExercisePersonalRecord('exercise-1')).thenAnswer(
          (_) async => Right<Failure, WorkoutSet?>(personalRecordSet),
        );
        when(() => mockGetMuscleVisualData(TimePeriod.week)).thenAnswer(
          (_) async => Right<Failure, Map<String, MuscleVisualData>>(
            <String, MuscleVisualData>{
              'upper-chest': visual(muscle: 'upper-chest', intensity: 0.55),
              'mid-chest': visual(muscle: 'mid-chest', intensity: 0.30),
              'triceps': visual(muscle: 'triceps', intensity: 0.20),
            },
          ),
        );

        // Prime the weekly cache so setsToday/volumeToday can compute.
        when(
          () => mockGetWeeklySets(),
        ).thenAnswer((_) async => Right(weeklySets));
        bloc.add(const LoadWeeklySetsEvent());
        await Future<void>.delayed(Duration.zero);

        bloc.add(SelectExerciseForInsightEvent(exercise));
        await Future<void>.delayed(Duration.zero);

        final state = bloc.state;
        expect(state, isA<WorkoutLoaded>());
        final loaded = state as WorkoutLoaded;
        final insight = loaded.selectedInsight;
        expect(insight, isNotNull);
        expect(insight!.exerciseId, 'exercise-1');
        expect(insight.personalRecord?.id, 'pr-set');
        expect(insight.setsToday, 2);
        expect(insight.volumeTodayKg, 80 * 10 + 80 * 8);
        expect(insight.muscles.length, 2);
        // chest picked the max sub-muscle (upper-chest 0.55 → 55%).
        final chest = insight.muscles.firstWhere(
          (m) => m.coarseGroup == 'chest',
        );
        expect(chest.percent, 55);
        final triceps = insight.muscles.firstWhere(
          (m) => m.coarseGroup == 'triceps',
        );
        expect(triceps.percent, 20);
      },
    );

    test('logging a set recomputes insight with refreshed data', () async {
      // First selection: PR 90, fatigue 0.20.
      when(() => mockGetExercisePersonalRecord('exercise-1')).thenAnswer(
        (_) async =>
            Right<Failure, WorkoutSet?>(personalRecordSet.copyWith(weight: 90)),
      );
      when(() => mockGetMuscleVisualData(TimePeriod.week)).thenAnswer(
        (_) async => Right<Failure, Map<String, MuscleVisualData>>(
          <String, MuscleVisualData>{
            'upper-chest': visual(muscle: 'upper-chest', intensity: 0.20),
          },
        ),
      );
      when(
        () => mockGetWeeklySets(),
      ).thenAnswer((_) async => Right(weeklySets));

      bloc.add(const LoadWeeklySetsEvent());
      await Future<void>.delayed(Duration.zero);
      bloc.add(SelectExerciseForInsightEvent(exercise));
      await Future<void>.delayed(Duration.zero);

      // Now log a set: PR climbs to 105, fatigue jumps to 0.80.
      when(
        () => mockGetExercisePersonalRecord('exercise-1'),
      ).thenAnswer((_) async => Right<Failure, WorkoutSet?>(personalRecordSet));
      when(() => mockGetMuscleVisualData(TimePeriod.week)).thenAnswer(
        (_) async => Right<Failure, Map<String, MuscleVisualData>>(
          <String, MuscleVisualData>{
            'upper-chest': visual(muscle: 'upper-chest', intensity: 0.80),
          },
        ),
      );
      when(
        () => mockAddWorkoutSet(workoutSet),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockCalculateMuscleStimulus.calculateForSet(
          exerciseId: workoutSet.exerciseId,
          sets: 1,
          intensity: workoutSet.intensity,
        ),
      ).thenAnswer((_) async => const Right({'upper-chest': 1.0}));

      bloc.add(AddWorkoutSetEvent(workoutSet));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = bloc.state;
      expect(state, isA<WorkoutLoaded>());
      final loaded = state as WorkoutLoaded;
      final insight = loaded.selectedInsight;
      expect(insight, isNotNull);
      expect(insight!.personalRecord?.weight, 105);
      final chest = insight.muscles.firstWhere((m) => m.coarseGroup == 'chest');
      expect(chest.percent, 80);
    });

    test('clear insight emits WorkoutLoaded without insight', () async {
      when(
        () => mockGetWeeklySets(),
      ).thenAnswer((_) async => Right(weeklySets));
      bloc.add(const LoadWeeklySetsEvent());
      await Future<void>.delayed(Duration.zero);

      bloc.add(SelectExerciseForInsightEvent(exercise));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ClearExerciseInsightEvent());
      await Future<void>.delayed(Duration.zero);

      final state = bloc.state;
      expect(state, isA<WorkoutLoaded>());
      expect((state as WorkoutLoaded).selectedInsight, isNull);
    });
  });
}
