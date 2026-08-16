import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
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
    // Rewritten from the pre-restyle "renders header, meal names, and macro
    // pills (kcal/P/C/F)" test. Task 17 (Spec B, PR B2) drops the P/C/F pill
    // row entirely — CONTROLLER AMENDMENT C in b-task-17-brief.md specifies
    // the meal row's right side is only the kcal value (LiftNumber, dataSmall)
    // beside a "KCAL / 100G" label. The P/C/F assertions are superseded by
    // that spec, not dropped for convenience.
    testWidgets('renders header, meal name, and the kcal metadata', (
      tester,
    ) async {
      await pumpPicker(tester, meals: <Meal>[chicken]);

      expect(find.text(AppStrings.selectMeal), findsOneWidget);
      expect(find.text('Chicken Breast'), findsOneWidget);
      expect(find.text('165'), findsOneWidget);
      expect(find.text('KCAL / 100G'), findsOneWidget);
      // The old P/C/F pills are gone.
      expect(find.text('P 31'), findsNothing);
      expect(find.text('C 0'), findsNothing);
      expect(find.text('F 4'), findsNothing);
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

  group('MealPickerSheet Deep Mist chrome', () {
    testWidgets('panel is square (BorderRadius.zero)', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken]);

      final Container panel = tester.widget<Container>(
        find.byKey(const ValueKey<String>('meal-picker-panel')),
      );
      final BoxDecoration decoration = panel.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.zero);
    });

    testWidgets('selected row has actionWash background and w700 name weight', (
      tester,
    ) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice], selected: chicken);

      final Container row = tester.widget<Container>(
        find.byKey(const ValueKey<String>('meal-row-meal-chicken')),
      );
      final BoxDecoration decoration = row.decoration! as BoxDecoration;
      expect(decoration.color, LiftColors.actionWash);

      final Text name = tester.widget<Text>(find.text('Chicken Breast'));
      expect(name.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('unselected row has no actionWash background', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      final Container row = tester.widget<Container>(
        find.byKey(const ValueKey<String>('meal-row-meal-chicken')),
      );
      final BoxDecoration decoration = row.decoration! as BoxDecoration;
      expect(decoration.color, isNot(LiftColors.actionWash));
    });

    testWidgets('kcal/100g label uses JetBrainsMono, no Chip present', (
      tester,
    ) async {
      await pumpPicker(tester, meals: <Meal>[chicken]);

      final Text label = tester.widget<Text>(find.text('KCAL / 100G'));
      expect(label.style?.fontFamily, 'JetBrainsMono');
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('shows a right-aligned result count', (tester) async {
      await pumpPicker(tester, meals: <Meal>[chicken, rice]);

      expect(find.text('2 ITEMS'), findsOneWidget);
    });

    testWidgets(
      'the modal chrome draws no border of its own — only the panel\'s '
      "borderStrong edge shows, so the hairline isn't doubled",
      (tester) async {
        await pumpPicker(tester, meals: <Meal>[chicken]);

        // showModalBottomSheet's default chrome (bottomSheetTheme.shape)
        // paints a dimmer LiftColors.border edge via an ancestor Material.
        // The picker overrides that shape to borderless so only the panel
        // Container's own borderStrong edge (below) is visible.
        final Iterable<Material> materials = tester.widgetList<Material>(
          find.byType(Material),
        );
        for (final Material material in materials) {
          final ShapeBorder? shape = material.shape;
          if (shape is RoundedRectangleBorder) {
            expect(
              shape.side,
              BorderSide.none,
              reason:
                  'a modal-chrome Material must not draw its own visible '
                  'border side — the picker panel already owns the seam',
            );
          }
        }

        final Container panel = tester.widget<Container>(
          find.byKey(const ValueKey<String>('meal-picker-panel')),
        );
        final BoxDecoration decoration = panel.decoration! as BoxDecoration;
        final Border border = decoration.border! as Border;
        expect(border.top.color, LiftColors.borderStrong);
        expect(border.top.width, LiftShape.borderWidth);
      },
    );
  });
}
