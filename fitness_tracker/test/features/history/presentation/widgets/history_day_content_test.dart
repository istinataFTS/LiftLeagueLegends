import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:fitness_tracker/features/history/presentation/widgets/history_day_content.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../support/phone_viewport.dart';

class MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class FakeHistoryEvent extends Fake implements HistoryEvent {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

void main() {
  late MockHistoryBloc historyBloc;
  late MockExerciseBloc exerciseBloc;

  final DateTime day = DateTime(2026, 8, 8);

  final Exercise cableCrossover = Exercise(
    id: 'e1',
    name: 'Cable Crossover',
    muscleGroups: const <String>['chest'],
    createdAt: day,
  );

  WorkoutSet buildSet(String id, double weight, int intensity) => WorkoutSet(
    id: id,
    exerciseId: 'e1',
    reps: 12,
    weight: weight,
    intensity: intensity,
    date: day,
    createdAt: day,
  );

  final List<WorkoutSet> sets = <WorkoutSet>[
    buildSet('s1', 15, 1),
    buildSet('s2', 42.5, 1),
    buildSet('s3', 37, 4),
  ];

  final NutritionLog mealLog = NutritionLog(
    id: 'n1',
    mealName: 'Chicken breast',
    proteinGrams: 78,
    carbsGrams: 0,
    fatGrams: 9,
    calories: 391,
    gramsConsumed: 250,
    loggedAt: DateTime(2026, 8, 8, 14, 39),
    createdAt: day,
  );

  setUpAll(() {
    registerFallbackValue(FakeHistoryEvent());
    registerFallbackValue(FakeExerciseEvent());
  });

  setUp(() {
    historyBloc = MockHistoryBloc();
    exerciseBloc = MockExerciseBloc();

    when(() => historyBloc.add(any())).thenReturn(null);
    when(() => exerciseBloc.add(any())).thenReturn(null);
    when(
      () => exerciseBloc.state,
    ).thenReturn(ExercisesLoaded(<Exercise>[cableCrossover]));
    whenListen(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: ExercisesLoaded(<Exercise>[cableCrossover]),
    );
  });

  Widget buildSubject({
    bool daySelected = true,
    List<WorkoutSet> workoutSets = const <WorkoutSet>[],
    List<NutritionLog> nutritionLogs = const <NutritionLog>[],
  }) {
    return AppShell(
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<HistoryBloc>.value(value: historyBloc),
          BlocProvider<ExerciseBloc>.value(value: exerciseBloc),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: HistoryDayContent(
              selectedDate: daySelected ? day : null,
              workoutSets: workoutSets,
              nutritionLogs: nutritionLogs,
              weightUnit: WeightUnit.kilograms,
            ),
          ),
        ),
      ),
    );
  }

  group('HistoryDayContent — frame 09/10 chrome', () {
    testWidgets('draws no add, edit, delete or chevron control', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(workoutSets: sets, nutritionLogs: <NutritionLog>[mealLog]),
      );

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('day strip reads as SAT · AUG 8 with the day counts', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(workoutSets: sets, nutritionLogs: <NutritionLog>[mealLog]),
      );

      expect(find.text('SAT · AUG 8'), findsOneWidget);
      expect(find.text('3 SETS · 1 ENTRY · 391 KCAL'), findsOneWidget);
    });

    testWidgets('workout subtitle counts sets and the muscles hit', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      expect(find.text('3 SETS · CHEST ×3'), findsOneWidget);
    });
  });

  group('HistoryDayContent — workout rows', () {
    testWidgets('effort fills by count, one mark per level', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      // Three rows x five marks.
      final List<Container> marks = tester
          .widgetList<Container>(
            find.byWidgetPredicate(
              (Widget w) =>
                  w is Container &&
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                    'history-effort-mark-',
                  ),
            ),
          )
          .toList();

      expect(marks, hasLength(15));

      final int lit = marks
          .where((Container c) => c.color == LiftColors.effortOn)
          .length;

      // Intensities 1, 1 and 4.
      expect(lit, 6);
    });

    testWidgets('the day total is volume, not weight', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      // 15x12 + 42.5x12 + 37x12 == 1134.
      expect(find.text('DAY TOTAL'), findsOneWidget);
      expect(find.text('1134'), findsOneWidget);
      expect(find.text('KG'), findsOneWidget);
    });

    testWidgets('long-pressing a row opens the delete confirmation', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      await tester.longPress(find.text('Cable Crossover').first);
      await tester.pumpAndSettle();

      expect(find.text('Delete Set?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => historyBloc.add(any(that: isA<DeleteSetEvent>()))).called(1);
    });
  });

  group('HistoryDayContent — nutrition rows', () {
    testWidgets('totals row spells out every macro and the calories', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(nutritionLogs: <NutritionLog>[mealLog]),
      );

      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FATS'), findsOneWidget);
      // Once as the totals column label, once on the single entry's row.
      expect(find.text('KCAL'), findsNWidgets(2));
      // On a day with no sets the strip and the section subtitle say the
      // same thing.
      expect(find.text('1 ENTRY · 391 KCAL'), findsNWidgets(2));
    });

    testWidgets('an entry row carries its time, kcal and amount', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(nutritionLogs: <NutritionLog>[mealLog]),
      );

      expect(find.text('Chicken breast'), findsOneWidget);
      expect(find.text('14:39'), findsOneWidget);
      // The day has one entry, so the day total and the row carry the same
      // number at two different data sizes.
      expect(find.text('391'), findsNWidgets(2));
      expect(find.text('250 G'), findsOneWidget);
    });

    testWidgets('long-pressing an entry opens the delete confirmation', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(nutritionLogs: <NutritionLog>[mealLog]),
      );

      await tester.longPress(find.text('Chicken breast'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Nutrition Log?'), findsOneWidget);
    });
  });

  group('HistoryDayContent — empty states', () {
    testWidgets('no day selected shows the prompt, not the sections', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(daySelected: false));

      expect(find.text('NO DAY SELECTED'), findsOneWidget);
      expect(find.text('Workout history'), findsNothing);
    });

    testWidgets('an empty day still offers a way to log into it', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('LOG WORKOUT · AUG 8'), findsOneWidget);
      expect(find.text('LOG NUTRITION · AUG 8'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
