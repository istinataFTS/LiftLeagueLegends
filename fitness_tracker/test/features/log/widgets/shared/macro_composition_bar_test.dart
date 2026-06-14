import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/macro_composition_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// find.text() does not search inside RichText spans; use this helper instead.
Finder _findRichTextContaining(String text) => find.byWidgetPredicate(
  (Widget w) => w is RichText && w.text.toPlainText().contains(text),
);

void main() {
  Widget buildSubject({
    double proteinGrams = 0,
    double carbsGrams = 0,
    double fatsGrams = 0,
    bool disableAnimations = false,
  }) {
    return AppShell(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MacroCompositionBar(
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatsGrams: fatsGrams,
          ),
        ),
      ),
    );
  }

  group('MacroCompositionBar', () {
    testWidgets('renders without error when all grams are zero', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(MacroCompositionBar), findsOneWidget);
    });

    testWidgets('shows 0% for all macros when all are zero', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Finder bar = _findRichTextContaining('0% protein');
      expect(bar, findsOneWidget);
      expect(_findRichTextContaining('0% carbs'), findsOneWidget);
      expect(_findRichTextContaining('0% fats'), findsOneWidget);
    });

    testWidgets('pure protein shows 100% protein and 0% for carbs and fats', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(proteinGrams: 100));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('100% protein'), findsOneWidget);
      expect(_findRichTextContaining('0% carbs'), findsOneWidget);
      expect(_findRichTextContaining('0% fats'), findsOneWidget);
    });

    testWidgets('pure fats shows 100% fats', (tester) async {
      await tester.pumpWidget(buildSubject(fatsGrams: 100));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('100% fats'), findsOneWidget);
      expect(_findRichTextContaining('0% protein'), findsOneWidget);
      expect(_findRichTextContaining('0% carbs'), findsOneWidget);
    });

    testWidgets('equal protein and carbs split ~50/50', (tester) async {
      // 50g protein = 200 kcal, 50g carbs = 200 kcal → 50% each
      await tester.pumpWidget(buildSubject(proteinGrams: 50, carbsGrams: 50));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('50% protein'), findsOneWidget);
      expect(_findRichTextContaining('50% carbs'), findsOneWidget);
      expect(_findRichTextContaining('0% fats'), findsOneWidget);
    });

    testWidgets('fats dominate with 9 kcal/g vs 4 kcal/g', (tester) async {
      // 10g protein = 40 kcal, 10g fats = 90 kcal → total 130 kcal
      // protein 31%, fats 69%
      await tester.pumpWidget(buildSubject(proteinGrams: 10, fatsGrams: 10));
      await tester.pumpAndSettle();

      expect(_findRichTextContaining('31% protein'), findsOneWidget);
      expect(_findRichTextContaining('69% fats'), findsOneWidget);
    });

    testWidgets('renders without error with reduced-motion flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          proteinGrams: 30,
          carbsGrams: 30,
          fatsGrams: 10,
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MacroCompositionBar), findsOneWidget);
    });
  });
}
