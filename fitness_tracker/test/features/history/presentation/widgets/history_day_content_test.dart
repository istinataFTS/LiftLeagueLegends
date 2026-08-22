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
import 'package:flutter/semantics.dart';
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

  final Exercise barbellRow = Exercise(
    id: 'e2',
    name: 'Barbell Row',
    muscleGroups: const <String>['back'],
    createdAt: day,
  );

  WorkoutSet buildSet(
    String id, {
    String exerciseId = 'e1',
    double weight = 20,
    int intensity = 1,
    int minute = 0,
  }) => WorkoutSet(
    id: id,
    exerciseId: exerciseId,
    reps: 12,
    weight: weight,
    intensity: intensity,
    date: day,
    createdAt: DateTime(2026, 8, 8, 10, minute),
  );

  final List<WorkoutSet> sets = <WorkoutSet>[
    buildSet('s1', weight: 15),
    buildSet('s2', weight: 42.5, minute: 1),
    buildSet('s3', weight: 37, intensity: 4, minute: 2),
  ];

  /// Two exercises alternating — the shape a superset actually logs in.
  final List<WorkoutSet> supersetSets = <WorkoutSet>[
    buildSet('a1'),
    buildSet('b1', exerciseId: 'e2', minute: 1),
    buildSet('a2', minute: 2),
    buildSet('b2', exerciseId: 'e2', minute: 3),
    buildSet('a3', minute: 4),
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

    final ExercisesLoaded loaded = ExercisesLoaded(<Exercise>[
      cableCrossover,
      barbellRow,
    ]);

    when(() => historyBloc.add(any())).thenReturn(null);
    when(() => exerciseBloc.add(any())).thenReturn(null);
    when(() => exerciseBloc.state).thenReturn(loaded);
    whenListen(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: loaded,
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

  Future<void> toggleGroup(WidgetTester tester, String exerciseName) async {
    await tester.tap(find.text(exerciseName));
    await tester.pumpAndSettle();
  }

  group('HistoryDayContent — chrome', () {
    testWidgets('there is no line naming the selected day', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(workoutSets: sets, nutritionLogs: <NutritionLog>[mealLog]),
      );

      // The calendar above already shows which day is selected.
      expect(find.text('SAT · AUG 8'), findsNothing);
      expect(find.text('3 SETS · 1 ENTRY · 391 KCAL'), findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('there is no muscle filter row', (WidgetTester tester) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      // The row led with an `ALL` chip and then listed every muscle group,
      // trained or not. `CHEST` still appears — as the group's own muscle
      // line — but `BACK`, which this day never touched, would only be here
      // as a filter chip.
      expect(find.text('ALL'), findsNothing);
      expect(find.text('BACK'), findsNothing);
      expect(find.text('CHEST'), findsOneWidget);
    });

    testWidgets('the workout header carries an add control', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      expect(
        find.byKey(const ValueKey<String>('history-add-set-button')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('the add control sits outside the collapse target', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      final Rect addRect = tester.getRect(
        find.byKey(const ValueKey<String>('history-add-set-button')),
      );
      final Rect headerRect = tester.getRect(
        find
            .ancestor(
              of: find.text('Workout history'),
              matching: find.byType(InkWell),
            )
            .first,
      );

      expect(headerRect.overlaps(addRect), isFalse);
    });

    testWidgets('workout subtitle counts sets and the muscles hit', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));

      expect(find.text('3 SETS · CHEST ×3'), findsOneWidget);
    });
  });

  group('HistoryDayContent — exercise groups', () {
    testWidgets('a superset day renders one row per exercise, not per set', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: supersetSets));

      // Five sets across two exercises collapse to two rows.
      expect(find.text('Cable Crossover'), findsOneWidget);
      expect(find.text('Barbell Row'), findsOneWidget);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);

      // Nothing is expanded, so no set rows are painted.
      expect(
        find.byKey(const ValueKey<String>('history-effort-mark-0')),
        findsNothing,
      );
      expectNoOverflow(tester);
    });

    testWidgets('groups are ordered by when the exercise was first logged', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: supersetSets));

      final double crossover = tester
          .getTopLeft(find.text('Cable Crossover'))
          .dy;
      final double row = tester.getTopLeft(find.text('Barbell Row')).dy;

      expect(crossover, lessThan(row));
    });

    testWidgets('group order survives the newest-first list the bloc emits', (
      WidgetTester tester,
    ) async {
      // `HistoryBloc._loadMonthData` sorts each day's sets **descending** by
      // `createdAt`, so this is the order the real widget is handed. Grouping
      // must not inherit it — the day still reads Cable Crossover first
      // because that is the exercise the day opened with.
      final List<WorkoutSet> newestFirst = List<WorkoutSet>.from(supersetSets)
        ..sort(
          (WorkoutSet a, WorkoutSet b) => b.createdAt.compareTo(a.createdAt),
        );

      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: newestFirst));

      final double crossover = tester
          .getTopLeft(find.text('Cable Crossover'))
          .dy;
      final double row = tester.getTopLeft(find.text('Barbell Row')).dy;

      expect(crossover, lessThan(row));
    });

    testWidgets('sets inside a group read oldest first whatever the input '
        'order', (WidgetTester tester) async {
      final List<WorkoutSet> newestFirst = List<WorkoutSet>.from(sets)
        ..sort(
          (WorkoutSet a, WorkoutSet b) => b.createdAt.compareTo(a.createdAt),
        );

      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: newestFirst));
      await toggleGroup(tester, 'Cable Crossover');

      // Row identity, not row position: the ordinals 1..3 are painted in
      // order whatever the sets do, so they cannot show a mis-ordering.
      final double first = tester
          .getTopLeft(find.byKey(const ValueKey<String>('history-edit-set-s1')))
          .dy;
      final double last = tester
          .getTopLeft(find.byKey(const ValueKey<String>('history-edit-set-s3')))
          .dy;

      expect(first, lessThan(last));
    });

    testWidgets('a group header carries its own volume', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: supersetSets));

      // 3 x 20kg x 12 == 720; 2 x 20kg x 12 == 480.
      expect(find.text('720 KG'), findsOneWidget);
      expect(find.text('480 KG'), findsOneWidget);
    });

    testWidgets(
      'tapping a group reveals its sets and tapping again hides them',
      (WidgetTester tester) async {
        await pumpAtPhoneWidth(tester, buildSubject(workoutSets: supersetSets));

        await toggleGroup(tester, 'Cable Crossover');

        // Three sets, numbered within the group.
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        await toggleGroup(tester, 'Cable Crossover');

        expect(find.text('1'), findsNothing);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      },
    );

    testWidgets('expanding one group leaves the other collapsed', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: supersetSets));

      await toggleGroup(tester, 'Barbell Row');

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });
  });

  group('HistoryDayContent — set rows', () {
    testWidgets('effort fills by count, one mark per level', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));
      await toggleGroup(tester, 'Cable Crossover');

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

    testWidgets('every set offers both edit and delete', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));
      await toggleGroup(tester, 'Cable Crossover');

      for (final WorkoutSet s in sets) {
        expect(
          find.byKey(ValueKey<String>('history-edit-set-${s.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('history-delete-set-${s.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('the edit control opens the edit dialog', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));
      await toggleGroup(tester, 'Cable Crossover');

      await tester.tap(
        find.byKey(const ValueKey<String>('history-edit-set-s1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Set'), findsOneWidget);
    });

    testWidgets('the row controls keep a 44dp target and a semantic tap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));
      await toggleGroup(tester, 'Cable Crossover');

      for (final String key in <String>[
        'history-edit-set-s1',
        'history-delete-set-s1',
        'history-add-set-button',
      ]) {
        final Finder finder = find.byKey(ValueKey<String>(key));

        // Edit and delete sit side by side and one of them is destructive.
        final Size size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
        expect(size.height, greaterThanOrEqualTo(44), reason: key);

        // `excludeSemantics` drops the GestureDetector's own tap action, so
        // the wrapping node has to publish one itself or the control is
        // unreachable from assistive technology.
        expect(
          tester
              .getSemantics(finder)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
          reason: '$key must be activatable by assistive technology',
        );
      }

      handle.dispose();
    });

    testWidgets('an orphaned set keeps delete but loses edit', (
      WidgetTester tester,
    ) async {
      // A set can outlive the library entry it points at; the row still has
      // to render and still has to delete. Edit is the only thing that goes,
      // because the dialog needs the exercise to name what is being edited.
      final WorkoutSet orphan = buildSet('o1', exerciseId: 'gone');

      await pumpAtPhoneWidth(
        tester,
        buildSubject(workoutSets: <WorkoutSet>[orphan]),
      );
      await toggleGroup(tester, 'Unknown exercise');

      await tester.tap(
        find.byKey(const ValueKey<String>('history-edit-set-o1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Set'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('history-delete-set-o1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete Set?'), findsOneWidget);
    });

    testWidgets('the delete control opens the delete confirmation', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject(workoutSets: sets));
      await toggleGroup(tester, 'Cable Crossover');

      await tester.tap(
        find.byKey(const ValueKey<String>('history-delete-set-s1')),
      );
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
      // Only the section subtitle carries it now — the day strip that used to
      // repeat it is gone.
      expect(find.text('1 ENTRY · 391 KCAL'), findsOneWidget);
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
