import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:fitness_tracker/features/library/presentation/library_page.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/exercises_tab.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/meals_tab.dart';
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
    await tester.tap(find.text('Meals'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders tabs and initial exercise result count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Meals'), findsOneWidget);
    expect(find.byKey(ExercisesTab.resultCountKey), findsOneWidget);
    expect(find.text('3 of 3 exercises'), findsOneWidget);
  });

  testWidgets('filters exercises by search query', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byKey(ExercisesTab.searchFieldKey), 'bench');
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsNothing);
    expect(find.text('Overhead Press'), findsNothing);
    expect(find.text('1 of 3 exercises'), findsOneWidget);
  });

  testWidgets('filters exercises by muscle chip', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byKey(ExercisesTab.muscleChipKey('chest')));
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull Up'), findsNothing);
    expect(find.text('Overhead Press'), findsNothing);
    expect(find.text('1 of 3 exercises'), findsOneWidget);
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

    expect(find.text('3 of 3 exercises'), findsOneWidget);
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
    expect(find.text('1 of 2 meals'), findsOneWidget);
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

    expect(find.text('2 of 2 meals'), findsOneWidget);
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

  testWidgets('about dialog is shown from info action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.byTooltip('About Library'));
    await tester.pumpAndSettle();

    expect(find.text('About Library'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
  });
}
