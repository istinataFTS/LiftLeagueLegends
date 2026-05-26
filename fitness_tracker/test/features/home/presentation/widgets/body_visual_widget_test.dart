import 'package:fitness_tracker/features/home/presentation/home_page_keys.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/body_visual_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('BodyVisualWidget', () {
    testWidgets('renders the front side and a flip control by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(BodyVisualWidget(viewData: buildViewData())),
      );
      await tester.pump();

      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(find.byKey(HomePageKeys.bodyVisualFlipButtonKey), findsOneWidget);
      expect(find.text('Show back'), findsOneWidget);
    });

    testWidgets('flips to the back side when the flip control is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(BodyVisualWidget(viewData: buildViewData())),
      );
      await tester.pump();

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Front'), findsNothing);
      expect(find.text('Show front'), findsOneWidget);
    });

    testWidgets('flips back to the front on a second tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(BodyVisualWidget(viewData: buildViewData())),
      );
      await tester.pump();

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Front'), findsOneWidget);
      expect(find.text('Show back'), findsOneWidget);
    });

    testWidgets('honours initialSide override', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          BodyVisualWidget(
            viewData: buildViewData(),
            initialSide: BodySide.back,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Show front'), findsOneWidget);
    });

    testWidgets('does not render the removed Sets/Target/Muscles labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(BodyVisualWidget(viewData: buildViewData())),
      );
      await tester.pump();

      expect(find.text('Sets'), findsNothing);
      expect(find.text('Target'), findsNothing);
      expect(find.text('Muscles'), findsNothing);
    });
  });
}
