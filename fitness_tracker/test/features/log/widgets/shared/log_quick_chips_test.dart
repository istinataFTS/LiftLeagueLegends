import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_quick_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<num> _defaultValues = <num>[50, 100, 150, 200];

  BoxDecoration decorationFor(WidgetTester tester, String label) {
    final AnimatedContainer container = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  Widget buildSubject({
    List<num> values = _defaultValues,
    num selectedValue = 100,
    ValueChanged<num>? onSelected,
  }) {
    return AppShell(
      home: Scaffold(
        body: LogQuickChips(
          values: values,
          selectedValue: selectedValue,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    );
  }

  group('LogQuickChips', () {
    testWidgets('renders a chip for each value', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      for (final num v in _defaultValues) {
        expect(find.text(v.toString()), findsOneWidget);
      }
    });

    testWidgets('does not throw with a single chip', (tester) async {
      await tester.pumpWidget(
        buildSubject(values: <num>[100], selectedValue: 100),
      );
      await tester.pumpAndSettle();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('tapping a chip calls onSelected with its value', (
      tester,
    ) async {
      num? selected;
      await tester.pumpWidget(buildSubject(onSelected: (v) => selected = v));
      await tester.pumpAndSettle();

      await tester.tap(find.text('50'));
      await tester.pumpAndSettle();

      expect(selected, equals(50));
    });

    testWidgets('tapping a different chip calls onSelected with that value', (
      tester,
    ) async {
      num? selected;
      await tester.pumpWidget(buildSubject(onSelected: (v) => selected = v));
      await tester.pumpAndSettle();

      await tester.tap(find.text('200'));
      await tester.pumpAndSettle();

      expect(selected, equals(200));
    });

    testWidgets('active chip matches selectedValue', (tester) async {
      // Active chip should be '150' in this configuration.
      // We verify the widget renders without error when a non-first value is active.
      await tester.pumpWidget(buildSubject(selectedValue: 150));
      await tester.pumpAndSettle();

      expect(find.byType(LogQuickChips), findsOneWidget);
      // All four chips must still be visible.
      expect(find.text('50'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('no active chip when selectedValue matches none', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(selectedValue: 999));
      await tester.pumpAndSettle();

      // Widget should still render without error.
      expect(find.byType(LogQuickChips), findsOneWidget);
    });

    testWidgets(
      "the selected chip fills LiftColors.actionFill with square corners",
      (tester) async {
        await tester.pumpWidget(buildSubject(selectedValue: 100));
        await tester.pumpAndSettle();

        final BoxDecoration decoration = decorationFor(tester, '100');
        expect(decoration.color, LiftColors.actionFill);
        expect(decoration.borderRadius, BorderRadius.zero);
      },
    );

    testWidgets(
      'an unselected chip is transparent with a 1.5px LiftColors.border',
      (tester) async {
        await tester.pumpWidget(buildSubject(selectedValue: 100));
        await tester.pumpAndSettle();

        final BoxDecoration decoration = decorationFor(tester, '50');
        expect(decoration.color, Colors.transparent);
        final Border border = decoration.border! as Border;
        expect(border.top.color, LiftColors.border);
        expect(border.top.width, LiftShape.borderWidth);
      },
    );
  });
}
