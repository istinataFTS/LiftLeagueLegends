import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
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
        child: const SettingsScope(child: Scaffold(body: LogExerciseTab())),
      ),
    );
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

    testWidgets('submits selected exercise, reps, and weight', (tester) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: ExercisesLoaded(exercises)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.selectExercise));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '10');
      await tester.enterText(find.byType(TextField).at(1), '80');

      await tester.ensureVisible(find.text(AppStrings.logSetButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.logSetButton));
      await tester.pump();

      verify(
        () => workoutBloc.add(
          any(
            that: isA<AddWorkoutSetEvent>().having(
              (e) => e.workoutSet.exerciseId,
              'exerciseId',
              'exercise-1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('shows muscle group info after exercise selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(exerciseState: ExercisesLoaded(exercises)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.selectExercise));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bench Press').last);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.setWillCountToward), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
    });
  });
}
