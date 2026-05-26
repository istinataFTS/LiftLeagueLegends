import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class FakeHistoryEvent extends Fake implements HistoryEvent {}

class FakeHistoryState extends Fake implements HistoryState {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

class FakeExerciseState extends Fake implements ExerciseState {}

void main() {
  late MockHistoryBloc historyBloc;
  late MockExerciseBloc exerciseBloc;

  final DateTime januaryMonth = DateTime(2024, 1, 1);
  final DateTime selectedDate = DateTime(2024, 1, 15);

  final Exercise benchPress = Exercise(
    id: 'exercise-1',
    name: 'Bench Press',
    muscleGroups: const <String>['chest'],
    createdAt: DateTime(2024, 1, 1),
  );

  final WorkoutSet workoutSet = WorkoutSet(
    id: 'set-1',
    exerciseId: 'exercise-1',
    reps: 10,
    weight: 80,
    date: selectedDate,
    createdAt: selectedDate.add(const Duration(hours: 1)),
  );

  final NutritionLog nutritionLog = NutritionLog(
    id: 'log-1',
    mealName: 'Chicken Bowl',
    proteinGrams: 40,
    carbsGrams: 55,
    fatGrams: 12,
    calories: 488,
    loggedAt: selectedDate,
    createdAt: selectedDate.add(const Duration(minutes: 20)),
  );

  setUpAll(() {
    registerFallbackValue(FakeHistoryEvent());
    registerFallbackValue(FakeHistoryState());
    registerFallbackValue(FakeExerciseEvent());
    registerFallbackValue(FakeExerciseState());
  });

  setUp(() {
    historyBloc = MockHistoryBloc();
    exerciseBloc = MockExerciseBloc();

    when(
      () => historyBloc.effects,
    ).thenAnswer((_) => const Stream<HistoryUiEffect>.empty());
    when(() => historyBloc.add(any())).thenReturn(null);
    when(() => exerciseBloc.add(any())).thenReturn(null);

    when(
      () => exerciseBloc.state,
    ).thenReturn(ExercisesLoaded(<Exercise>[benchPress]));
    whenListen(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: ExercisesLoaded(<Exercise>[benchPress]),
    );
  });

  Widget buildSubject(HistoryState historyState) {
    when(() => historyBloc.state).thenReturn(historyState);
    whenListen(
      historyBloc,
      const Stream<HistoryState>.empty(),
      initialState: historyState,
    );

    return AppShell(
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<HistoryBloc>.value(value: historyBloc),
          BlocProvider<ExerciseBloc>.value(value: exerciseBloc),
        ],
        child: const HistoryPage(settings: AppSettings.defaults()),
      ),
    );
  }

  group('HistoryPage', () {
    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(buildSubject(const HistoryLoading()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loaded state', (tester) async {
      final HistoryLoaded state = HistoryLoaded(
        currentMonth: januaryMonth,
        monthSets: <DateTime, List<WorkoutSet>>{
          selectedDate: <WorkoutSet>[workoutSet],
        },
        monthNutritionLogs: <DateTime, List<NutritionLog>>{
          selectedDate: <NutritionLog>[nutritionLog],
        },
        selectedDate: selectedDate,
        selectedDateSets: <WorkoutSet>[workoutSet],
        selectedDateNutritionLogs: <NutritionLog>[nutritionLog],
      );

      await tester.pumpWidget(buildSubject(state));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.text('Workout history'), findsOneWidget);
      expect(find.text('Nutrition history'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Chicken Bowl'), findsOneWidget);
    });

    testWidgets('shows error state and retry action dispatches load event', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(const HistoryError('Something went wrong')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      reset(historyBloc);
      when(
        () => historyBloc.effects,
      ).thenAnswer((_) => const Stream<HistoryUiEffect>.empty());
      when(() => historyBloc.add(any())).thenReturn(null);
      when(
        () => historyBloc.state,
      ).thenReturn(const HistoryError('Something went wrong'));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(
        () => historyBloc.add(any(that: isA<LoadMonthSetsEvent>())),
      ).called(1);
    });

    testWidgets('tapping a calendar date dispatches SelectDateEvent', (
      tester,
    ) async {
      final HistoryLoaded state = HistoryLoaded(
        currentMonth: januaryMonth,
        monthSets: <DateTime, List<WorkoutSet>>{
          selectedDate: <WorkoutSet>[workoutSet],
        },
        monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
        selectedDate: null,
        selectedDateSets: const <WorkoutSet>[],
        selectedDateNutritionLogs: const <NutritionLog>[],
      );

      await tester.pumpWidget(buildSubject(state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pump();

      verify(
        () => historyBloc.add(SelectDateEvent(DateTime(2024, 1, 15))),
      ).called(1);
    });

    testWidgets('previous month button dispatches NavigateToMonthEvent', (
      tester,
    ) async {
      final HistoryLoaded state = HistoryLoaded(
        currentMonth: januaryMonth,
        monthSets: const <DateTime, List<WorkoutSet>>{},
        monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
      );

      await tester.pumpWidget(buildSubject(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Previous Month'));
      await tester.pump();

      verify(
        () => historyBloc.add(NavigateToMonthEvent(DateTime(2023, 12, 1))),
      ).called(1);
    });

    testWidgets('next month navigation is blocked for future months', (
      tester,
    ) async {
      final DateTime now = DateTime.now();
      final DateTime currentMonth = DateTime(now.year, now.month, 1);

      final HistoryLoaded state = HistoryLoaded(
        currentMonth: currentMonth,
        monthSets: const <DateTime, List<WorkoutSet>>{},
        monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
      );

      await tester.pumpWidget(buildSubject(state));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next Month'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot view future months'), findsOneWidget);

      verifyNever(
        () => historyBloc.add(
          NavigateToMonthEvent(DateTime(now.year, now.month + 1, 1)),
        ),
      );
    });
  });
}
