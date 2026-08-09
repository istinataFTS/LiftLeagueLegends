import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/meal_picker_sheet.dart';
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

  Widget buildSubject({
    required MealState mealState,
    NutritionLogState? nutritionState,
    DateTime? initialDate,
  }) {
    when(() => mealBloc.state).thenReturn(mealState);
    whenListen(
      mealBloc,
      const Stream<MealState>.empty(),
      initialState: mealState,
    );

    if (nutritionState != null) {
      when(() => nutritionBloc.state).thenReturn(nutritionState);
      whenListen(
        nutritionBloc,
        const Stream<NutritionLogState>.empty(),
        initialState: nutritionState,
      );
    }

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
    testWidgets(
      'select-meal bar shows the default prompt before any selection',
      (tester) async {
        await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
        await tester.pumpAndSettle();

        // No dock yet (no meal selected).
        expect(find.text(AppStrings.logMealButton), findsNothing);
        // Bar shows "Select Meal" prompt.
        expect(find.text(AppStrings.selectMeal), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the bar opens the picker sheet; selecting a meal fills the bar '
      'and reveals the dock',
      (tester) async {
        await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.selectMeal));
        await tester.pumpAndSettle();

        // Picker is open.
        expect(find.byType(MealPickerSheet), findsOneWidget);
        // Picker shows both meals.
        expect(find.text('Chicken Breast'), findsOneWidget);
        expect(find.text('White Rice'), findsOneWidget);

        await tester.tap(find.text('Chicken Breast'));
        await tester.pumpAndSettle();

        // Picker dismissed; bar + dock both show the meal name; dock appears.
        expect(find.byType(MealPickerSheet), findsNothing);
        expect(find.text('Chicken Breast'), findsNWidgets(2));
        expect(find.text(AppStrings.logMealButton), findsOneWidget);
        expect(find.text('per 100 g'), findsOneWidget);
      },
    );

    testWidgets('tapping a quick chip updates grams and preview', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.selectMeal));
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
      'log dispatches AddNutritionLogEvent with correct grams + macros',
      (tester) async {
        await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.selectMeal));
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

    testWidgets('opens keypad on value tap and submits via ✓', (tester) async {
      await tester.pumpWidget(buildSubject(mealState: MealsLoaded(meals)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.selectMeal));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chicken Breast'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('mealGramsStepper')),
          matching: find.text('100'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter grams'), findsOneWidget);

      await tester.tap(find.text('2'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('✓'));
      await tester.pumpAndSettle();

      expect(find.text('per 250 g'), findsOneWidget);
    });

    testWidgets(
      'Today so far renders when nutrition state is DailyLogsLoaded for the date',
      (tester) async {
        final DateTime today = DateTime.now();
        final DateTime dateOnly = DateTime(today.year, today.month, today.day);

        await tester.pumpWidget(
          buildSubject(
            mealState: MealsLoaded(meals),
            initialDate: dateOnly,
            nutritionState: DailyLogsLoaded(
              date: dateOnly,
              logs: <NutritionLog>[
                NutritionLog(
                  id: 'a',
                  mealId: null,
                  mealName: 'x',
                  gramsConsumed: null,
                  proteinGrams: 30,
                  carbsGrams: 40,
                  fatGrams: 10,
                  calories: 370,
                  loggedAt: dateOnly,
                  createdAt: dateOnly,
                ),
              ],
              dailyMacros: const <String, double>{
                'protein': 30,
                'carbs': 40,
                'fats': 10,
                'calories': 370,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Today so far'), findsOneWidget);
        expect(find.text('370 kcal · 1 log'), findsOneWidget);
      },
    );

    testWidgets(
      'picker is reachable even when no meals are loaded (empty library)',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(mealState: const MealsLoaded(<Meal>[])),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.selectMeal));
        await tester.pumpAndSettle();

        expect(find.byType(MealPickerSheet), findsOneWidget);
        // Sectioned empty: "All Meals" header only, no rows.
        expect(find.text(AppStrings.pickerAllMeals), findsOneWidget);
      },
    );
  });
}
