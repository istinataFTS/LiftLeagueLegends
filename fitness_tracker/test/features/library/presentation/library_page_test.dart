import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:fitness_tracker/features/library/presentation/library_page.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/exercises_tab.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/exercise_dialog.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/meals_tab.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/presentation/shared/widgets/lift_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class MockMealBloc extends MockBloc<MealEvent, MealState> implements MealBloc {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

class FakeExerciseState extends Fake implements ExerciseState {}

class FakeMealEvent extends Fake implements MealEvent {}

class FakeMealState extends Fake implements MealState {}

void main() {
  late MockExerciseBloc exerciseBloc;
  late MockMealBloc mealBloc;

  final DateTime createdAt = DateTime(2026, 1, 1);

  ExercisesLoaded buildExercisesLoaded() {
    return ExercisesLoaded(<Exercise>[
      Exercise(
        id: '1',
        name: 'Bench Press',
        muscleGroups: const <String>['chest'],
        createdAt: createdAt,
      ),
      Exercise(
        id: '2',
        name: 'Pull Up',
        muscleGroups: const <String>['back'],
        createdAt: createdAt,
      ),
      Exercise(
        id: '3',
        name: 'Overhead Press',
        muscleGroups: const <String>['shoulders'],
        createdAt: createdAt,
      ),
    ]);
  }

  MealsLoaded buildMealsLoaded() {
    return MealsLoaded(<Meal>[
      Meal(
        id: 'm1',
        name: 'Chicken Bowl',
        servingSizeGrams: 100,
        proteinPer100g: 30,
        carbsPer100g: 20,
        fatPer100g: 10,
        caloriesPer100g: 290,
        createdAt: createdAt,
      ),
      Meal(
        id: 'm2',
        name: 'Oats',
        servingSizeGrams: 100,
        proteinPer100g: 12,
        carbsPer100g: 60,
        fatPer100g: 7,
        caloriesPer100g: 347,
        createdAt: createdAt,
      ),
    ]);
  }

  setUpAll(() {
    registerFallbackValue(FakeExerciseEvent());
    registerFallbackValue(FakeExerciseState());
    registerFallbackValue(FakeMealEvent());
    registerFallbackValue(FakeMealState());
  });

  setUp(() {
    exerciseBloc = MockExerciseBloc();
    mealBloc = MockMealBloc();

    final ExercisesLoaded exercisesState = buildExercisesLoaded();
    final MealsLoaded mealsState = buildMealsLoaded();

    when(() => exerciseBloc.state).thenReturn(exercisesState);
    whenListen<ExerciseState>(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: exercisesState,
    );

    when(() => mealBloc.state).thenReturn(mealsState);
    whenListen<MealState>(
      mealBloc,
      const Stream<MealState>.empty(),
      initialState: mealsState,
    );
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ExerciseBloc>.value(value: exerciseBloc),
        BlocProvider<MealBloc>.value(value: mealBloc),
      ],
      child: const MaterialApp(home: LibraryPage()),
    );
  }

  Future<void> openMealsTab(WidgetTester tester) async {
    await tester.tap(find.text('MEALS'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders tabs and initial exercise result count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('EXERCISES'), findsOneWidget);
    expect(find.text('MEALS'), findsOneWidget);
    expect(find.byKey(ExercisesTab.resultCountKey), findsOneWidget);
    expect(find.text('3 OF 3 EXERCISES'), findsOneWidget);
  });

  testWidgets('filters exercises by search query', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byKey(ExercisesTab.searchFieldKey), 'bench');
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsNothing);
    expect(find.text('Overhead Press'), findsNothing);
    expect(find.text('1 OF 3 EXERCISES'), findsOneWidget);
  });

  testWidgets('filters exercises by muscle chip', (WidgetTester tester) async {
    // Use a wide viewport so all 18 canonical muscle filter chips are visible.
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(ExercisesTab.muscleChipKey('chest')));
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsNothing);
    expect(find.text('Overhead Press'), findsNothing);
    expect(find.text('1 OF 3 EXERCISES'), findsOneWidget);
  });

  testWidgets('exercise filters reset from no-results state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byKey(ExercisesTab.searchFieldKey), 'legs');
    await tester.pump();

    expect(
      find.text('No exercises match the current search or filter.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ExercisesTab.clearFiltersButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('3 OF 3 EXERCISES'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsOneWidget);
    expect(find.text('Overhead Press'), findsOneWidget);
  });

  testWidgets('exercise retry dispatches load event from error state', (
    WidgetTester tester,
  ) async {
    when(
      () => exerciseBloc.state,
    ).thenReturn(const ExerciseError('exercise load failed'));
    whenListen<ExerciseState>(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: const ExerciseError('exercise load failed'),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(ExercisesTab.retryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(ExercisesTab.retryButtonKey));
    await tester.pump();

    verify(() => exerciseBloc.add(LoadExercisesEvent())).called(1);
  });

  testWidgets('switches to meals tab and filters meals by search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await openMealsTab(tester);

    await tester.enterText(find.byKey(MealsTab.searchFieldKey), 'chicken');
    await tester.pump();

    expect(find.text('Chicken Bowl'), findsOneWidget);
    expect(find.text('Oats'), findsNothing);
    expect(find.text('1 OF 2 MEALS'), findsOneWidget);
  });

  testWidgets('meal search resets from no-results state', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await openMealsTab(tester);

    await tester.enterText(find.byKey(MealsTab.searchFieldKey), 'salmon');
    await tester.pump();

    expect(find.text('No meals match the current search.'), findsOneWidget);

    await tester.tap(find.byKey(MealsTab.clearResultsButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('2 OF 2 MEALS'), findsOneWidget);
    expect(find.text('Chicken Bowl'), findsOneWidget);
    expect(find.text('Oats'), findsOneWidget);
  });

  testWidgets('meal retry dispatches load event from error state', (
    WidgetTester tester,
  ) async {
    when(() => mealBloc.state).thenReturn(const MealError('meal load failed'));
    whenListen<MealState>(
      mealBloc,
      const Stream<MealState>.empty(),
      initialState: const MealError('meal load failed'),
    );

    await tester.pumpWidget(buildSubject());
    await openMealsTab(tester);

    expect(find.byKey(MealsTab.retryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(MealsTab.retryButtonKey));
    await tester.pump();

    verify(() => mealBloc.add(LoadMealsEvent())).called(1);
  });

  // ---------------------------------------------------------------------
  // Frame 11 — what the rebuild removed. Each of these fails against the
  // pre-restyle page, which is the only reason they are worth asserting.
  // ---------------------------------------------------------------------

  testWidgets('the AppBar carries no action — the info dialog is gone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byTooltip('About Library'), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the tabs are text only and carry no icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(LiftTabSelector), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsNothing);
  });

  testWidgets('the Scaffold is transparent so LiftGround shows through', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, anyOf(isNull, Colors.transparent));
  });

  testWidgets('rows are rules, not cards — no Card and no overflow menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.byType(Card), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('the muscle line is mono caps joined by a spaced middot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    final Text meta = tester.widget<Text>(find.text('CHEST'));
    expect(meta.style!.fontFamily, 'JetBrainsMono');
    expect(meta.style!.color, LiftColors.textDim);
  });

  testWidgets('the selected filter chip fills actionFill, the rest are '
      'transparent behind a border', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());

    BoxDecoration decorationOf(Key key) {
      return tester
              .widget<Container>(
                find.descendant(
                  of: find.byKey(key),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    final BoxDecoration selected = decorationOf(ExercisesTab.allMusclesChipKey);
    expect(selected.color, LiftColors.actionFill);
    expect(selected.border, isNull);
    expect(selected.borderRadius, isNull);

    final BoxDecoration unselected = decorationOf(
      ExercisesTab.muscleChipKey('chest'),
    );
    expect(unselected.color, Colors.transparent);
    expect(unselected.border, isNotNull);
    expect(unselected.borderRadius, isNull);
  });

  testWidgets('tapping a row opens the edit dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Edit exercise'), findsOneWidget);
    expect(find.byKey(ExerciseDialog.deleteButtonKey), findsOneWidget);
  });

  testWidgets('long-pressing a row asks to delete it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.longPress(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Delete exercise'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(
      () => exerciseBloc.add(any(that: isA<DeleteExerciseEvent>())),
    ).called(1);
  });

  testWidgets('the add control rides the search row, not a bottom dock', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    final Rect search = tester.getRect(find.byKey(ExercisesTab.searchFieldKey));
    final Rect add = tester.getRect(find.byKey(ExercisesTab.addButtonKey));

    // Same line, immediately to its right, and small — the old control was a
    // full-width dock pinned to the bottom of the page, stacked directly on
    // top of the app's bottom navigation.
    expect(add.left, greaterThanOrEqualTo(search.right));
    expect(add.center.dy, moreOrLessEquals(search.center.dy, epsilon: 1));
    expect(add.width, lessThan(search.width));
    expect(add.height, search.height);
  });

  testWidgets('the title scrolls away and the tab strip stays', (
    WidgetTester tester,
  ) async {
    // Short enough that the header plus three rows overflow it by more than
    // the title's own height, or the title never clears the top edge.
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildSubject());

    final double stripTopAtRest = tester.getTopLeft(find.text('EXERCISES')).dy;
    expect(
      tester.getTopLeft(find.text('Library')).dy,
      lessThan(stripTopAtRest),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // The title is gone — scrolled past the viewport's cache extent and torn
    // down — while the strip has pinned itself at the top rather than
    // travelling with it.
    expect(find.text('Library'), findsNothing);
    expect(
      tester.getTopLeft(find.text('EXERCISES')).dy,
      lessThan(stripTopAtRest),
    );
    expect(
      tester.getTopLeft(find.text('EXERCISES')).dy,
      greaterThanOrEqualTo(0),
    );
    expect(find.text('MEALS'), findsOneWidget);
  });

  testWidgets('the tabs no longer swipe — the page navigation owns that', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    // A nested horizontal scrollable would win the gesture from the shell's
    // `PageView` and make Library the one page a swipe cannot leave.
    expect(find.byType(TabBarView), findsNothing);
    expect(find.byType(PageView), findsNothing);

    await tester.drag(find.text('3 OF 3 EXERCISES'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('3 OF 3 EXERCISES'), findsOneWidget);
    expect(find.byKey(MealsTab.searchFieldKey), findsNothing);
  });

  testWidgets('every key ExercisesTab declares still resolves', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());

    for (final Key key in <Key>[
      ExercisesTab.searchFieldKey,
      ExercisesTab.allMusclesChipKey,
      ExercisesTab.resultCountKey,
      ExercisesTab.addButtonKey,
      ExercisesTab.muscleChipKey('chest'),
    ]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }

    await tester.enterText(find.byKey(ExercisesTab.searchFieldKey), 'bench');
    await tester.pump();
    expect(find.byKey(ExercisesTab.clearSearchButtonKey), findsOneWidget);
  });
}
