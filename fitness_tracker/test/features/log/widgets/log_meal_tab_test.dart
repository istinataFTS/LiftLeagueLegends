import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/meal_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

class MockMealBloc extends MockBloc<MealEvent, MealState> implements MealBloc {}

class FakeNutritionLogEvent extends Fake implements NutritionLogEvent {}

class FakeNutritionLogState extends Fake implements NutritionLogState {}

class FakeMealEvent extends Fake implements MealEvent {}

class FakeMealState extends Fake implements MealState {}

void main() {
  late MockNutritionLogBloc nutritionBloc;
  late MockMealBloc mealBloc;

  final List<Meal> meals = <Meal>[
    Meal(
      id: 'meal-chicken',
      name: 'Chicken Breast',
      servingSizeGrams: 100,
      proteinPer100g: 31,
      carbsPer100g: 0,
      fatPer100g: 4,
      caloriesPer100g: 165,
      createdAt: DateTime(2024, 1, 1),
    ),
    Meal(
      id: 'meal-rice',
      name: 'White Rice',
      servingSizeGrams: 100,
      proteinPer100g: 2,
      carbsPer100g: 28,
      fatPer100g: 0,
      caloriesPer100g: 130,
      createdAt: DateTime(2024, 1, 1),
    ),
  ];

  setUpAll(() {
    registerFallbackValue(FakeNutritionLogEvent());
    registerFallbackValue(FakeNutritionLogState());
    registerFallbackValue(FakeMealEvent());
    registerFallbackValue(FakeMealState());
  });

  setUp(() {
    nutritionBloc = MockNutritionLogBloc();
    mealBloc = MockMealBloc();

    when(
      () => nutritionBloc.effects,
    ).thenAnswer((_) => const Stream<NutritionLogUiEffect>.empty());
    when(() => nutritionBloc.add(any())).thenReturn(null);
    when(() => mealBloc.add(any())).thenReturn(null);

    when(() => nutritionBloc.state).thenReturn(NutritionLogInitial());
    whenListen(
      nutritionBloc,
      const Stream<NutritionLogState>.empty(),
      initialState: NutritionLogInitial(),
    );
  });

  Widget buildSubject({required MealState mealState, DateTime? initialDate}) {
    when(() => mealBloc.state).thenReturn(mealState);
    whenListen(
      mealBloc,
      const Stream<MealState>.empty(),
      initialState: mealState,
    );

    return AppShell(
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<NutritionLogBloc>.value(value: nutritionBloc),
          BlocProvider<MealBloc>.value(value: mealBloc),
        ],
        child: Scaffold(body: LogMealTab(initialDate: initialDate)),
      ),
    );
  }

  group('LogMealTab', () {
    testWidgets('shows loading while meals load', (tester) async {
      await tester.pumpWidget(buildSubject(mealState: MealLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no meals exist', (tester) async {
      await tester.pumpWidget(
        buildSubject(mealState: const MealsLoaded(<Meal>[])),
      );

      expect(find.text(AppStrings.noMealsInLibrary), findsOneWidget);
      expect(find.text(AppStrings.createMealsInLibrary), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(buildSubject(mealState: const MealError('boom')));

      expect(find.text(AppStrings.errorLoadingMeals), findsOneWidget);
      await tester.tap(find.text(AppStrings.retry));
      await tester.pump();

      verify(() => mealBloc.add(LoadMealsEvent())).called(1);
    });

    testWidgets('search filters the meal list', (tester) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      expect(find.byType(MealListRow), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'rice');
      await tester.pumpAndSettle();

      expect(find.text('White Rice'), findsOneWidget);
      expect(find.text('Chicken Breast'), findsNothing);
    });

    testWidgets('shows no-results state when search has no matches', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No meals found'), findsOneWidget);
    });

    testWidgets('selecting a meal reveals the dock + log button', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.logMealButton), findsNothing);

      await tester.tap(find.text('Chicken Breast'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.logMealButton), findsOneWidget);
      // Default grams = 100.
      expect(find.text('per 100 g'), findsOneWidget);
    });

    testWidgets('tapping a quick chip updates grams and preview', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chicken Breast'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('150'));
      await tester.pumpAndSettle();

      // Preview updates: 150g of chicken at 31g protein per 100g = 47g (round).
      expect(find.text('47g'), findsOneWidget);
      expect(find.text('per 150 g'), findsOneWidget);
    });

    testWidgets(
      'stepper + button updates grams; log dispatches AddNutritionLogEvent with '
      'correct grams and macros',
      (tester) async {
        await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chicken Breast'));
        await tester.pumpAndSettle();

        // Default 100 → bump grams via +.
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('mealGramsStepper')),
            matching: find.text('+'),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.logMealButton));
        await tester.pump();

        verify(
          () => nutritionBloc.add(
            any(
              that: isA<AddNutritionLogEvent>()
                  .having((e) => e.log.mealId, 'mealId', 'meal-chicken')
                  .having((e) => e.log.mealName, 'mealName', 'Chicken Breast')
                  .having((e) => e.log.gramsConsumed, 'grams', 110.0)
                  .having(
                    (e) => e.log.proteinGrams,
                    'protein',
                    closeTo(31 * 1.1, 0.0001),
                  )
                  .having(
                    (e) => e.log.calories,
                    'calories',
                    closeTo((31 * 4 + 0 * 4 + 4 * 9) * 1.1, 0.0001),
                  ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('opens keypad on value tap and submits via Done', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chicken Breast'));
      await tester.pumpAndSettle();

      // Tap the stepper value (the '100' inside the grams stepper).
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('mealGramsStepper')),
          matching: find.text('100'),
        ),
      );
      await tester.pumpAndSettle();

      // Keypad header label.
      expect(find.text('Enter grams'), findsOneWidget);

      // Enter 250, confirm.
      await tester.tap(find.text('2'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('✓'));
      await tester.pumpAndSettle();

      expect(find.text('per 250 g'), findsOneWidget);
    });

    testWidgets('hides date pill when showDatePill = false', (tester) async {
      when(() => mealBloc.state).thenReturn(MealsLoaded(meals));
      whenListen(
        mealBloc,
        const Stream<MealState>.empty(),
        initialState: MealsLoaded(meals),
      );

      await tester.pumpWidget(
        AppShell(
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<NutritionLogBloc>.value(value: nutritionBloc),
              BlocProvider<MealBloc>.value(value: mealBloc),
            ],
            child: const Scaffold(body: LogMealTab(showDatePill: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today), findsNothing);
    });
  });
}
