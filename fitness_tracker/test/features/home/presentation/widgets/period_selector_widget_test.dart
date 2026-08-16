import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/period_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    TimePeriod selectedPeriod = TimePeriod.month,
    ValueChanged<TimePeriod>? onPeriodChanged,
    bool enabled = true,
  }) {
    return AppShell(
      home: Scaffold(
        body: PeriodSelectorWidget(
          selectedPeriod: selectedPeriod,
          onPeriodChanged: onPeriodChanged ?? (TimePeriod _) {},
          enabled: enabled,
        ),
      ),
    );
  }

  group('PeriodSelectorWidget', () {
    testWidgets('the selector is square and 1.5px bordered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Container container = tester.widget<Container>(
        find.byKey(PeriodSelectorWidget.containerKey),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      expect(decoration.borderRadius, isNull);
      expect(decoration.color, LiftColors.surface);
      expect(decoration.border!.top.color, LiftColors.border);
      expect(decoration.border!.top.width, LiftShape.borderWidth);
    });

    testWidgets('the selected value renders as mono caps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Text valueText = tester.widget<Text>(find.text('MONTH'));

      expect(valueText.style?.fontFamily, 'JetBrainsMono');
    });

    testWidgets('the menu items carry no icons', (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(PeriodSelectorWidget.dropdownKey));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(PeriodSelectorWidget.menuItemKey(TimePeriod.month)),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(PeriodSelectorWidget.menuItemKey(TimePeriod.allTime)),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });

    testWidgets('selecting a period reports it', (WidgetTester tester) async {
      TimePeriod? reported;

      await tester.pumpWidget(
        buildSubject(onPeriodChanged: (TimePeriod period) => reported = period),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(PeriodSelectorWidget.dropdownKey));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(PeriodSelectorWidget.menuItemKey(TimePeriod.allTime)).last,
      );
      await tester.pumpAndSettle();

      expect(reported, TimePeriod.allTime);
    });

    testWidgets('a disabled selector does not open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject(enabled: false));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(PeriodSelectorWidget.dropdownKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(PeriodSelectorWidget.menuItemKey(TimePeriod.allTime)),
        findsNothing,
      );
    });
  });
}
