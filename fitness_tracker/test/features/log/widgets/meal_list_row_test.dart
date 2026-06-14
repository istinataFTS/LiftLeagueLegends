import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/app_theme.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/meal_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Meal buildMeal({String name = 'Chicken Breast'}) {
    return Meal(
      id: 'meal-1',
      name: name,
      servingSizeGrams: 100,
      carbsPer100g: 0,
      proteinPer100g: 31,
      fatPer100g: 4,
      caloriesPer100g: 165,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  Widget buildSubject({
    required Meal meal,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return AppShell(
      home: Scaffold(
        body: MealListRow(
          meal: meal,
          isSelected: isSelected,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  group('MealListRow', () {
    testWidgets('renders name, per-100g micro-macros, and kcal/100g', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(meal: buildMeal(), isSelected: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chicken Breast'), findsOneWidget);
      // Calories rounded per-100g.
      expect(find.text('165'), findsOneWidget);
      expect(find.text('/100g'), findsOneWidget);
      // Micro-macro labels (P / C / F + grams) appear inside one RichText each.
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('shows check icon and orange border when selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(meal: buildMeal(), isSelected: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      final bool hasOrangeBorder = tester
          .widgetList<Container>(find.byType(Container))
          .any((Container c) {
            final Object? deco = c.decoration;
            if (deco is! BoxDecoration) return false;
            final BoxBorder? border = deco.border;
            if (border is! Border) return false;
            return border.top.color == AppTheme.primaryOrange &&
                border.top.width == 2;
          });
      expect(hasOrangeBorder, isTrue);
    });

    testWidgets('tap fires onTap', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        buildSubject(meal: buildMeal(), isSelected: false, onTap: () => taps++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MealListRow));
      await tester.pumpAndSettle();

      expect(taps, equals(1));
    });

    testWidgets('does not render check icon when unselected', (tester) async {
      await tester.pumpWidget(
        buildSubject(meal: buildMeal(), isSelected: false),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
