import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_number.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/features/log/application/nutrition_log_bloc.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_today_so_far_card.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/macro_composition_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return AppShell(home: Scaffold(body: child));
  }

  DailyLogsLoaded loaded({
    required DateTime date,
    int logs = 1,
    double protein = 30,
    double carbs = 40,
    double fats = 10,
    double calories = 370,
  }) {
    return DailyLogsLoaded(
      date: date,
      logs: List<NutritionLog>.generate(
        logs,
        (int i) => NutritionLog(
          id: 'l$i',
          mealId: null,
          mealName: 'x',
          gramsConsumed: null,
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fats,
          calories: calories,
          loggedAt: date,
          createdAt: date,
        ),
      ),
      dailyMacros: <String, double>{
        'protein': protein * logs,
        'carbs': carbs * logs,
        'fats': fats * logs,
        'calories': calories * logs,
      },
    );
  }

  group('LogTodaySoFarCard', () {
    testWidgets('renders header + cells + composition bar when date matches', (
      tester,
    ) async {
      final DateTime today = DateTime.now();
      final DateTime dateOnly = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        wrap(
          LogTodaySoFarCard(
            state: loaded(date: dateOnly),
            selectedDate: dateOnly,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header is uppercase mono, per the design's labelLarge/textStrong.
      expect(find.text('TODAY SO FAR'), findsOneWidget);
      // Right-hand summary: the count is a glued-looking but spaced unit, so
      // it renders as two widgets — dataSmall count, labelLarge remainder.
      expect(find.text('370'), findsOneWidget);
      expect(find.text(' KCAL · 1 LOG'), findsOneWidget);
      // Macro grams are glued units — LiftNumber, not plain Text.
      expect(find.text('30g'), findsOneWidget);
      expect(find.text('40g'), findsOneWidget);
      expect(find.text('10g'), findsOneWidget);
      expect(find.byType(MacroCompositionBar), findsOneWidget);

      // The block is no longer a Card — it sits directly on the ground.
      expect(find.byType(Card), findsNothing);

      // The three macro values render through LiftNumber at dataMedium.
      final List<LiftNumber> numbers = tester
          .widgetList<LiftNumber>(find.byType(LiftNumber))
          .toList();
      expect(numbers, hasLength(3));
      for (final LiftNumber n in numbers) {
        expect(n.style.fontSize, LiftText.dataMedium.fontSize);
        expect(n.unit, 'g');
      }

      // Each swatch's colour matches its LiftColors macro token.
      final Container proteinSwatch = tester.widget<Container>(
        find.byKey(const ValueKey<String>('today-swatch-protein')),
      );
      final Container carbsSwatch = tester.widget<Container>(
        find.byKey(const ValueKey<String>('today-swatch-carbs')),
      );
      final Container fatsSwatch = tester.widget<Container>(
        find.byKey(const ValueKey<String>('today-swatch-fats')),
      );
      expect(proteinSwatch.color, LiftColors.protein);
      expect(carbsSwatch.color, LiftColors.carbs);
      expect(fatsSwatch.color, LiftColors.fats);
    });

    testWidgets('renders dated header when selected date is not today', (
      tester,
    ) async {
      final DateTime past = DateTime(2024, 1, 5);
      await tester.pumpWidget(
        wrap(
          LogTodaySoFarCard(
            state: loaded(date: past, logs: 0, calories: 0),
            selectedDate: past,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JAN 5 SO FAR'), findsOneWidget);
      expect(find.text('TODAY SO FAR'), findsNothing);
    });

    testWidgets('hides when state is not DailyLogsLoaded', (tester) async {
      await tester.pumpWidget(
        wrap(
          LogTodaySoFarCard(
            state: NutritionLogInitial(),
            selectedDate: DateTime(2026, 6, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SO FAR'), findsNothing);
      expect(find.byType(MacroCompositionBar), findsNothing);
    });

    testWidgets('hides when loaded date does not match selected date', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          LogTodaySoFarCard(
            state: loaded(date: DateTime(2026, 6, 13)),
            selectedDate: DateTime(2026, 6, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SO FAR'), findsNothing);
      expect(find.byType(MacroCompositionBar), findsNothing);
    });

    testWidgets('pluralises log count correctly (>1)', (tester) async {
      final DateTime today = DateTime.now();
      final DateTime dateOnly = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        wrap(
          LogTodaySoFarCard(
            state: loaded(
              date: dateOnly,
              logs: 3,
              protein: 10,
              carbs: 10,
              fats: 10,
              calories: 170,
            ),
            selectedDate: dateOnly,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('510'), findsOneWidget);
      expect(find.text(' KCAL · 3 LOGS'), findsOneWidget);
    });
  });
}
