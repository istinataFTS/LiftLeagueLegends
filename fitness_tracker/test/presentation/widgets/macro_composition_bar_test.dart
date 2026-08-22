import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/presentation/widgets/macro_composition_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    double proteinGrams = 0,
    double carbsGrams = 0,
    double fatsGrams = 0,
    bool disableAnimations = false,
    bool showPercentages = true,
  }) {
    return AppShell(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: MacroCompositionBar(
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatsGrams: fatsGrams,
            showPercentages: showPercentages,
          ),
        ),
      ),
    );
  }

  /// Reads the [BoxDecoration] off a keyed segment/track container, whichever
  /// widget type the implementation used (`Container` or `AnimatedContainer`).
  BoxDecoration decorationOf(WidgetTester tester, String key) {
    final Finder finder = find.byKey(ValueKey<String>(key));
    final Widget w = tester.widget(finder);
    if (w is Container) return w.decoration! as BoxDecoration;
    if (w is AnimatedContainer) return w.decoration! as BoxDecoration;
    throw StateError('Unexpected widget type for $key: ${w.runtimeType}');
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

      expect(find.textContaining('0% PROTEIN'), findsOneWidget);
      expect(find.textContaining('0% CARBS'), findsOneWidget);
      expect(find.textContaining('0% FATS'), findsOneWidget);
    });

    testWidgets('pure protein shows 100% protein and 0% for carbs and fats', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(proteinGrams: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('100% PROTEIN'), findsOneWidget);
      expect(find.textContaining('0% CARBS'), findsOneWidget);
      expect(find.textContaining('0% FATS'), findsOneWidget);
    });

    testWidgets('pure fats shows 100% fats', (tester) async {
      await tester.pumpWidget(buildSubject(fatsGrams: 100));
      await tester.pumpAndSettle();

      expect(find.textContaining('100% FATS'), findsOneWidget);
      expect(find.textContaining('0% PROTEIN'), findsOneWidget);
      expect(find.textContaining('0% CARBS'), findsOneWidget);
    });

    testWidgets('equal protein and carbs split ~50/50', (tester) async {
      // 50g protein = 200 kcal, 50g carbs = 200 kcal → 50% each
      await tester.pumpWidget(buildSubject(proteinGrams: 50, carbsGrams: 50));
      await tester.pumpAndSettle();

      expect(find.textContaining('50% PROTEIN'), findsOneWidget);
      expect(find.textContaining('50% CARBS'), findsOneWidget);
      expect(find.textContaining('0% FATS'), findsOneWidget);
    });

    testWidgets('fats dominate with 9 kcal/g vs 4 kcal/g', (tester) async {
      // 10g protein = 40 kcal, 10g fats = 90 kcal → total 130 kcal
      // protein 31%, fats 69%
      await tester.pumpWidget(buildSubject(proteinGrams: 10, fatsGrams: 10));
      await tester.pumpAndSettle();

      expect(find.textContaining('31% PROTEIN'), findsOneWidget);
      expect(find.textContaining('69% FATS'), findsOneWidget);
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

    testWidgets(
      'bar is 6px tall, square, and segments use the macro colour tokens '
      'with no radius',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(proteinGrams: 30, carbsGrams: 40, fatsGrams: 10),
        );
        await tester.pumpAndSettle();

        for (final String key in <String>[
          'macro-bar-protein',
          'macro-bar-carbs',
          'macro-bar-fats',
        ]) {
          final Finder finder = find.byKey(ValueKey<String>(key));
          expect(finder, findsOneWidget);
          final Size size = tester.getSize(finder);
          expect(size.height, 6);

          final BoxDecoration decoration = decorationOf(tester, key);
          expect(
            decoration.borderRadius == null ||
                decoration.borderRadius == BorderRadius.zero,
            isTrue,
            reason: '$key must have no radius, got ${decoration.borderRadius}',
          );
        }

        expect(
          decorationOf(tester, 'macro-bar-protein').color,
          LiftColors.protein,
        );
        expect(decorationOf(tester, 'macro-bar-carbs').color, LiftColors.carbs);
        expect(decorationOf(tester, 'macro-bar-fats').color, LiftColors.fats);
      },
    );

    testWidgets(
      'animates from empty to populated instead of popping segments in '
      '(the empty→data transition must keep the same element tree)',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Grab the empty-state AnimatedContainer elements so we can prove
        // they are the *same* elements after the data appears, not a
        // torn-down-and-rebuilt subtree.
        final Element proteinBefore = tester.element(
          find.byKey(const ValueKey<String>('macro-bar-protein')),
        );
        final Element carbsBefore = tester.element(
          find.byKey(const ValueKey<String>('macro-bar-carbs')),
        );
        final Element fatsBefore = tester.element(
          find.byKey(const ValueKey<String>('macro-bar-fats')),
        );

        await tester.pumpWidget(
          buildSubject(proteinGrams: 50, carbsGrams: 30, fatsGrams: 20),
        );
        // Advance only half of the 250ms animation duration.
        await tester.pump(const Duration(milliseconds: 125));

        // Same elements survived the transition — the tree was not torn
        // down and rebuilt.
        expect(
          tester.element(
            find.byKey(const ValueKey<String>('macro-bar-protein')),
          ),
          same(proteinBefore),
        );
        expect(
          tester.element(find.byKey(const ValueKey<String>('macro-bar-carbs'))),
          same(carbsBefore),
        );
        expect(
          tester.element(find.byKey(const ValueKey<String>('macro-bar-fats'))),
          same(fatsBefore),
        );

        // Mid-flight the protein segment should be animating towards its
        // target width, not already there and not still zero.
        final Size midSize = tester.getSize(
          find.byKey(const ValueKey<String>('macro-bar-protein')),
        );
        expect(midSize.width, greaterThan(0));

        await tester.pumpAndSettle();
        final Size finalSize = tester.getSize(
          find.byKey(const ValueKey<String>('macro-bar-protein')),
        );
        expect(finalSize.width, greaterThan(midSize.width));
      },
    );

    testWidgets('renders the percentage caption by default', (tester) async {
      await tester.pumpWidget(
        buildSubject(proteinGrams: 40, carbsGrams: 30, fatsGrams: 10),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('% PROTEIN'), findsOneWidget);
    });

    testWidgets('showPercentages false renders the bar and nothing else', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          proteinGrams: 40,
          carbsGrams: 30,
          fatsGrams: 10,
          showPercentages: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('% PROTEIN'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('macro-bar-track')),
        findsOneWidget,
      );
      // The caption and its 8px gap are both gone: the widget is exactly as
      // tall as the 6px bar.
      expect(tester.getSize(find.byType(MacroCompositionBar)).height, 6);
    });
  });
}
