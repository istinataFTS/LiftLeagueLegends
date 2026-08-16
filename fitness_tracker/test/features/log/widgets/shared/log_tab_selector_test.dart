import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../log_phone_viewport.dart';

void main() {
  Widget buildSubject({int selectedIndex = 0, ValueChanged<int>? onChanged}) {
    return AppShell(
      home: Scaffold(
        body: LogTabSelector(
          selectedIndex: selectedIndex,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  group('LogTabSelector', () {
    testWidgets('renders all three tab labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('EXERCISE'), findsOneWidget);
      expect(find.text('MEAL'), findsOneWidget);
      expect(find.text('MACROS'), findsOneWidget);
    });

    testWidgets('labels are mono JetBrainsMono', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Text label = tester.widget<Text>(find.text('EXERCISE'));
      expect(label.style!.fontFamily, 'JetBrainsMono');
    });

    testWidgets('the active tab is primary, inactive tabs are dim', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text('EXERCISE')).style!.color,
        LiftColors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('MEAL')).style!.color,
        LiftColors.textDim,
      );
    });

    testWidgets('the active tab carries a 2.5px tint underline', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(selectedIndex: 1));
      await tester.pumpAndSettle();

      final Container underline = tester.widget<Container>(
        find.byKey(const ValueKey<String>('log-tab-underline-1')),
      );
      expect(underline.constraints!.maxHeight, LiftShape.borderWidthActive);
      expect(
        (underline.decoration! as BoxDecoration).color,
        LiftColors.actionTint,
      );
    });

    testWidgets('the active tab underline actually renders with nonzero width, '
        'matching its label', (tester) async {
      await pumpAtPhoneWidth(tester, buildSubject(selectedIndex: 1));

      final Size underlineSize = tester.getSize(
        find.byKey(const ValueKey<String>('log-tab-underline-1')),
      );
      final Size labelSize = tester.getSize(find.text('MEAL'));

      expect(
        underlineSize.width,
        greaterThan(0),
        reason:
            'a childless Container with unbounded main-axis constraints '
            'collapses to zero width and never paints',
      );
      expect(underlineSize.width, closeTo(labelSize.width, 0.5));
      expectNoOverflow(tester);
    });

    testWidgets('no tab renders an icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('tapping Meal tab calls onChanged with index 1', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(buildSubject(onChanged: (i) => received = i));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MEAL'));
      await tester.pumpAndSettle();

      expect(received, equals(1));
    });

    testWidgets('tapping Macros tab calls onChanged with index 2', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(buildSubject(onChanged: (i) => received = i));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MACROS'));
      await tester.pumpAndSettle();

      expect(received, equals(2));
    });

    testWidgets('tapping Exercise tab calls onChanged with index 0', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(
        buildSubject(selectedIndex: 2, onChanged: (i) => received = i),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('EXERCISE'));
      await tester.pumpAndSettle();

      expect(received, equals(0));
    });

    testWidgets('does not throw with any valid index', (tester) async {
      for (final int i in <int>[0, 1, 2]) {
        await tester.pumpWidget(buildSubject(selectedIndex: i));
        await tester.pumpAndSettle();
        expect(find.byType(LogTabSelector), findsOneWidget);
      }
    });
  });
}
