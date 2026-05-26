import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/add_workout_set.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_weekly_sets.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddWorkoutSet extends Mock implements AddWorkoutSet {}

class MockGetWeeklySets extends Mock implements GetWeeklySets {}

class MockCalculateMuscleStimulus extends Mock
    implements CalculateMuscleStimulus {}

void main() {
  late MockAddWorkoutSet mockAddWorkoutSet;
  late MockGetWeeklySets mockGetWeeklySets;
  late MockCalculateMuscleStimulus mockCalculateMuscleStimulus;
  late WorkoutBloc bloc;

  final workoutSet = WorkoutSet(
    id: 'set-1',
    exerciseId: 'exercise-1',
    reps: 10,
    weight: 80,
    intensity: 3,
    date: DateTime(2024, 1, 15),
    createdAt: DateTime(2024, 1, 15, 10),
  );

  final weeklySets = [workoutSet, workoutSet.copyWith(id: 'set-2', reps: 8)];

  setUp(() {
    mockAddWorkoutSet = MockAddWorkoutSet();
    mockGetWeeklySets = MockGetWeeklySets();
    mockCalculateMuscleStimulus = MockCalculateMuscleStimulus();

    bloc = WorkoutBloc(
      addWorkoutSet: mockAddWorkoutSet,
      getWeeklySets: mockGetWeeklySets,
      calculateMuscleStimulus: mockCalculateMuscleStimulus,
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
  });
}
