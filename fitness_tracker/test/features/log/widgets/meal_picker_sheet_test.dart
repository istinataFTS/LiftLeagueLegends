import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/meal_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Meal chicken = Meal(
    id: 'meal-chicken',
    name: 'Chicken Breast',
    servingSizeGrams: 100,
    proteinPer100g: 31,
    carbsPer100g: 0,
    fatPer100g: 4,
    caloriesPer100g: 165,
    createdAt: DateTime(2024, 1, 1),
  );
  final Meal rice = Meal(
    id: 'meal-rice',
    name: 'White Rice',
    servingSizeGrams: 100,
    proteinPer100g: 2,
    carbsPer100g: 28,
    fatPer100g: 0,
    caloriesPer100g: 130,
    createdAt: DateTime(2024, 1, 1),
  );

  Future<void> pumpPicker(
    WidgetTester tester, {
    required List<Meal> meals,
    List<String> recentMealIds = const <String>[],
    Meal? selected,
  }) async {
    await tester.pumpWidget(
      AppShell(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => MealPickerSheet.show(
                    context,
                    meals: meals,
                    recentMealIds: recentMealIds,
                    selected: selected,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('MealPickerSheet', () {
    testWidgets('renders header, meal names, and macro pills (kcal/P/C/F)', (
      tester,
    ) async {
      await pumpPicker(tester, meals: <Meal>[chicken]);

      expect(find.text(AppStrings.selectMeal), findsOneWidget);
      expect(find.text('Chicken Breast'), findsOneWidget);
      expect(find.text('165 kcal'), findsOneWidget);
      expect(find.text('P 31'), findsOneWidget);
      expect(find.text('C 0'), findsOneWidget);
      expect(find.text('F 4'), findsOneWidget);
    });

    testWidgets('renders leading restaurant icon tile per row', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      expect(find.byIcon(Icons.restaurant), findsNWidgets(2));
    });

    testWidgets('selected row shows trailing check_circle', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice], selected: chicken);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('unselected rows show no check_circle', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('search filters the meal list', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      await tester.enterText(find.byType(TextField), 'rice');
      await tester.pumpAndSettle();

      expect(find.text('White Rice'), findsOneWidget);
      expect(find.text('Chicken Breast'), findsNothing);
    });

    testWidgets('shows "no results" when search has no matches', (
      tester,
    ) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.noResultsFound), findsOneWidget);
    });

    testWidgets('renders Recents section when recent ids are provided', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        meals: <Meal>[chicken, rice],
        recentMealIds: const <String>['meal-rice'],
      );

      expect(find.text(AppStrings.pickerRecents), findsOneWidget);
      expect(find.text(AppStrings.pickerAllMeals), findsOneWidget);
    });

    testWidgets('hides Recents section when no recent ids', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      expect(find.text(AppStrings.pickerRecents), findsNothing);
      expect(find.text(AppStrings.pickerAllMeals), findsOneWidget);
    });

    testWidgets('tapping a row pops with the chosen meal', (tester) async {
      Meal? popped;
      await tester.pumpWidget(
        AppShell(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped = await MealPickerSheet.show(
                        context,
                        meals: <Meal>[chicken, rice],
                        recentMealIds: const <String>[],
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('White Rice'));
      await tester.pumpAndSettle();

      expect(popped?.id, 'meal-rice');
    });
  });
}
