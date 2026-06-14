import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/log/application/exercise_insight.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class MockAppSettingsCubit extends MockCubit<AppSettingsState>
    implements AppSettingsCubit {}

class FakeWorkoutEvent extends Fake implements WorkoutEvent {}

class FakeWorkoutState extends Fake implements WorkoutState {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

class FakeExerciseState extends Fake implements ExerciseState {}

void main() {
  late MockWorkoutBloc workoutBloc;
  late MockExerciseBloc exerciseBloc;
  late MockAppSettingsCubit appSettingsCubit;

  final exercises = [
    Exercise(
      id: 'exercise-1',
      name: 'Bench Press',
      muscleGroups: const ['chest', 'triceps'],
      createdAt: DateTime(2024, 1, 1),
    ),
    Exercise(
      id: 'exercise-2',
      name: 'Squat',
      muscleGroups: const ['quads', 'glutes'],
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  ExerciseInsight benchInsight() {
    return ExerciseInsight(
      exerciseId: 'exercise-1',
      personalRecord: WorkoutSet(
        id: 'pr-set',
        exerciseId: 'exercise-1',
        reps: 3,
        weight: 105,
        intensity: 5,
        date: DateTime(2024, 6, 1),
        createdAt: DateTime(2024, 6, 1),
      ),
      setsToday: 3,
      volumeTodayKg: 2400,
      muscles: const <MuscleFatigue>[
        MuscleFatigue(
          coarseGroup: 'chest',
          displayName: 'Chest',
          percent: 42,
          bucket: MuscleVisualBucket.moderate,
          color: Color(0xFFFFEB3B),
        ),
      ],
    );
  }

  setUpAll(() {
    registerFallbackValue(FakeWorkoutEvent());
    registerFallbackValue(FakeWorkoutState());
    registerFallbackValue(FakeExerciseEvent());
    registerFallbackValue(FakeExerciseState());
  });

  setUp(() {
    workoutBloc = MockWorkoutBloc();
    exerciseBloc = MockExerciseBloc();
    appSettingsCubit = MockAppSettingsCubit();

    when(
      () => workoutBloc.effects,
    ).thenAnswer((_) => const Stream<WorkoutUiEffect>.empty());
    when(() => workoutBloc.add(any())).thenReturn(null);
    when(() => exerciseBloc.add(any())).thenReturn(null);
    when(
      () => appSettingsCubit.state,
    ).thenReturn(AppSettingsState.initial().copyWith(hasLoaded: true));
    whenListen(
      appSettingsCubit,
      const Stream<AppSettingsState>.empty(),
      initialState: AppSettingsState.initial().copyWith(hasLoaded: true),
    );

    when(() => workoutBloc.state).thenReturn(WorkoutInitial());
    whenListen(
      workoutBloc,
      const Stream<WorkoutState>.empty(),
      initialState: WorkoutInitial(),
    );
  });

  Widget buildSubject({
    required ExerciseState exerciseState,
    WorkoutState workoutState = const WorkoutLoaded([]),
    DateTime? initialDate,
  }) {
    when(() => exerciseBloc.state).thenReturn(exerciseState);
    whenListen(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: exerciseState,
    );

    when(() => workoutBloc.state).thenReturn(workoutState);
    whenListen(
      workoutBloc,
      const Stream<WorkoutState>.empty(),
      initialState: workoutState,
    );

    return AppShell(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AppSettingsCubit>.value(value: appSettingsCubit),
          BlocProvider<WorkoutBloc>.value(value: workoutBloc),
          BlocProvider<ExerciseBloc>.value(value: exerciseBloc),
        ],
        child: SettingsScope(
          child: Scaffold(body: LogExerciseTab(initialDate: initialDate)),
        ),
      ),
    );
  }

  Future<void> selectBenchPress(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.selectExercise));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press').last);
    await tester.pumpAndSettle();
  }

  group('LogExerciseTab', () {
    testWidgets('shows loading state while exercises load', (tester) async {
      await tester.pumpWidget(buildSubject(exerciseState: ExerciseLoading()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no exercises exist', (tester) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: const ExercisesLoaded([])),
      );

      expect(find.text(AppStrings.noExercisesAvailable), findsOneWidget);
      expect(find.text(AppStrings.createExercisesFirst), findsOneWidget);
    });

    testWidgets('shows retry state when exercises fail to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          exerciseState: const ExerciseError('Failed to load exercises'),
        ),
      );

      expect(find.text(AppStrings.errorLoadingExercises), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);

      await tester.tap(find.text(AppStrings.retry));
      await tester.pump();

      verify(() => exerciseBloc.add(LoadExercisesEvent())).called(1);
    });

    testWidgets('selecting an exercise dispatches insight event', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: ExercisesLoaded(exercises)),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      verify(
        () => workoutBloc.add(
          any(
            that: isA<SelectExerciseForInsightEvent>().having(
              (e) => e.exercise.id,
              'exercise.id',
              'exercise-1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('submits selected exercise, reps, and weight via steppers', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: ExercisesLoaded(exercises)),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      // Target each stepper by its stable key, not list order.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('exerciseRepsStepper')),
          matching: find.text('+'),
        ),
      ); // reps 0 -> 1
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('exerciseWeightStepper')),
          matching: find.text('+'),
        ),
      ); // weight 0 -> 2.5
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.logSetButton));
      await tester.pump();

      verify(
        () => workoutBloc.add(
          any(
            that: isA<AddWorkoutSetEvent>()
                .having(
                  (e) => e.workoutSet.exerciseId,
                  'exerciseId',
                  'exercise-1',
                )
                .having((e) => e.workoutSet.reps, 'reps', 1)
                .having((e) => e.workoutSet.weight, 'weight', 2.5),
          ),
        ),
      ).called(1);
    });

    testWidgets('renders PR badge and fatigue chip from insight; count is '
        'selected-date-based', (tester) async {
      WorkoutSet todaySet(String id) => WorkoutSet(
        id: id,
        exerciseId: 'exercise-1',
        reps: 8,
        weight: 80,
        intensity: 3,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildSubject(
          exerciseState: ExercisesLoaded(exercises),
          workoutState: WorkoutLoaded(<WorkoutSet>[
            todaySet('a'),
            todaySet('b'),
          ], selectedInsight: benchInsight()),
        ),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      // PR + fatigue come from the (now-based) insight.
      expect(find.text('PR 105 kg'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      // Count reflects the two sets logged for the selected date, not
      // insight.setsToday.
      expect(find.text('2 sets today'), findsOneWidget);
    });

    testWidgets('feed and labels follow a non-today selected date', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          exerciseState: ExercisesLoaded(exercises),
          initialDate: DateTime(2024, 1, 15),
        ),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      // Labels use the formatted date, never "today", for a past date.
      expect(find.text('Bench Press · Jan 15'), findsOneWidget);
      expect(find.text('No sets on Jan 15'), findsOneWidget);
      expect(find.text('0 sets Jan 15'), findsOneWidget);
      expect(find.textContaining('today'), findsNothing);
    });

    testWidgets('shows empty feed message when no sets logged today', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: ExercisesLoaded(exercises)),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      expect(find.text('No sets yet today'), findsOneWidget);
    });

    testWidgets('renders a set row for a set logged today', (tester) async {
      final WorkoutSet todaySet = WorkoutSet(
        id: 'set-1',
        exerciseId: 'exercise-1',
        reps: 8,
        weight: 100,
        intensity: 4,
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildSubject(
          exerciseState: ExercisesLoaded(exercises),
          workoutState: WorkoutLoaded(<WorkoutSet>[todaySet]),
        ),
      );
      await tester.pumpAndSettle();

      await selectBenchPress(tester);

      expect(find.text('Set 1'), findsOneWidget);
      expect(find.text('100 kg × 8'), findsOneWidget);
    });
  });
}
