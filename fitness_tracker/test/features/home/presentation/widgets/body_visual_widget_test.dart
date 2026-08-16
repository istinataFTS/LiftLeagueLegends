import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/home/presentation/home_page_keys.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/body_visual_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/phone_viewport.dart';

void main() {
  HomeBodyVisualViewData buildViewData() {
    return const HomeBodyVisualViewData(
      frontLayers: <HomeBodyOverlayViewData>[
        HomeBodyOverlayViewData(
          assetPath: 'assets/images/body/front_chest.png',
          color: Color(0xFF00FF00),
          opacity: 0.8,
          label: 'Chest',
        ),
      ],
      backLayers: <HomeBodyOverlayViewData>[
        HomeBodyOverlayViewData(
          assetPath: 'assets/images/body/back_lats.png',
          color: Color(0xFF0000FF),
          opacity: 0.6,
          label: 'Lats',
        ),
      ],
      subtitle: 'Front and back load',
    );
  }

  Widget buildSubject({BodySide initialSide = BodySide.front}) {
    return AppShell(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BodyVisualWidget(
            viewData: buildViewData(),
            initialSide: initialSide,
          ),
        ),
      ),
    );
  }

  group('BodyVisualWidget', () {
    testWidgets('renders the front side and a flip control by default', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('BACK'), findsNothing);
      expect(find.byKey(HomePageKeys.bodyVisualFlipButtonKey), findsOneWidget);
      expect(find.text('SHOW BACK'), findsOneWidget);
    });

    testWidgets('flips to the back side when the flip control is tapped', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('FRONT'), findsNothing);
      expect(find.text('SHOW FRONT'), findsOneWidget);
    });

    testWidgets('flips back to the front on a second tap', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('SHOW BACK'), findsOneWidget);
    });

    testWidgets('honours initialSide override', (WidgetTester tester) async {
      await pumpAtPhoneWidth(tester, buildSubject(initialSide: BodySide.back));

      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('SHOW FRONT'), findsOneWidget);
    });

    testWidgets('does not render the removed Sets/Target/Muscles labels', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('Sets'), findsNothing);
      expect(find.text('Target'), findsNothing);
      expect(find.text('Muscles'), findsNothing);
    });

    testWidgets('the panel fills the width and the remaining height', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Size panel = tester.getSize(
        find.byKey(HomePageKeys.bodyVisualPanelKey),
      );
      // 360 logical wide minus the 20px page gutters this test supplies.
      expect(panel.width, 320);
      // A width-capped figure could only reach 240 / 0.62 = 387 tall.
      expect(panel.height, greaterThan(500));
      expectNoOverflow(tester);
    });

    testWidgets('no 240px width cap survives', (tester) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Iterable<ConstrainedBox> capped = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((ConstrainedBox b) => b.constraints.maxWidth == 240);
      expect(capped, isEmpty);
    });

    testWidgets('the panel is square, surface-filled and 1.5px bordered', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Container panel = tester.widget<Container>(
        find.byKey(HomePageKeys.bodyVisualPanelKey),
      );
      final BoxDecoration d = panel.decoration! as BoxDecoration;
      expect(d.borderRadius, isNull);
      expect(d.color, LiftColors.surface);
      expect(d.border!.top.color, LiftColors.border);
      expect(d.border!.top.width, LiftShape.borderWidth);
    });

    testWidgets(
      'the side label is mono caps and the flip control is a themed filled button',
      (tester) async {
        await pumpAtPhoneWidth(tester, buildSubject());

        expect(
          tester.widget<Text>(find.text('FRONT')).style!.fontFamily,
          'JetBrainsMono',
        );

        final Finder flip = find.byKey(HomePageKeys.bodyVisualFlipButtonKey);
        expect(flip, findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        // No local style: the button must take LiftTheme's elevatedButtonTheme.
        expect(tester.widget<ElevatedButton>(flip).style, isNull);
        // The old pill control carried an Icons.cached glyph; the frame shows none.
        expect(
          find.descendant(of: flip, matching: find.byType(Icon)),
          findsNothing,
        );
      },
    );
  });
}
