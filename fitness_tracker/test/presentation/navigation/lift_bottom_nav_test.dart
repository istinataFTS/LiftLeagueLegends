import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/presentation/navigation/lift_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({int selectedIndex = 0, ValueChanged<int>? onTap}) {
    return MaterialApp(
      theme: LiftTheme.dark(),
      builder: (BuildContext context, Widget? child) =>
          LiftGround(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: LiftBottomNav(
          selectedIndex: selectedIndex,
          onTap: onTap ?? (int _) {},
        ),
      ),
    );
  }

  Color? colorOf(WidgetTester tester, String label) {
    return tester.widget<Text>(find.text(label)).style?.color;
  }

  group('LiftBottomNav', () {
    testWidgets('the bar paints nothing of its own', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // No slab and no bounding hairline: the bar stands on `LiftGround` the
      // way the Log page's tab strip does, and the ground runs straight
      // through it. Anything else read as a docked chrome bar and drew a
      // second horizontal line under pages that already end in one.
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(LiftBottomNav),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(boxes, isEmpty);

      final Iterable<Container> containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(LiftBottomNav),
          matching: find.byType(Container),
        ),
      );
      expect(containers, isEmpty);
    });

    testWidgets('the active tab is marked by tint alone', (
      WidgetTester tester,
    ) async {
      await pumpAndCheck(tester, buildSubject(selectedIndex: 2));

      expect(colorOf(tester, 'HISTORY'), LiftColors.actionTint);
      for (final String label in <String>[
        'HOME',
        'LOG',
        'LIBRARY',
        'PROFILE',
      ]) {
        expect(colorOf(tester, label), LiftColors.textDim, reason: label);
      }

      // The icon carries the same tint, and it is the only other thing that
      // changes — there is no marker bar over the active destination.
      final Icon active = tester.widget<Icon>(find.byIcon(Icons.history));
      expect(active.color, LiftColors.actionTint);
    });

    testWidgets('every destination reports its tap', (
      WidgetTester tester,
    ) async {
      final List<int> taps = <int>[];
      await pumpAndCheck(tester, buildSubject(onTap: taps.add));

      for (final String label in <String>[
        'HOME',
        'LOG',
        'HISTORY',
        'LIBRARY',
        'PROFILE',
      ]) {
        await tester.tap(find.text(label));
      }

      expect(taps, <int>[0, 1, 2, 3, 4]);
    });
  });
}

Future<void> pumpAndCheck(WidgetTester tester, Widget subject) async {
  await tester.pumpWidget(subject);
  await tester.pumpAndSettle();
}
