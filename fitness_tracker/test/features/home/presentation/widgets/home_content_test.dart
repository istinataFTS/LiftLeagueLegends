import 'dart:ui' as ui;

import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_number.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart'
    show MuscleMapMode;
import 'package:fitness_tracker/features/home/presentation/home_page_keys.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/home_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/phone_viewport.dart';

void main() {
  HomePageViewData buildViewData({
    MuscleMapMode mode = MuscleMapMode.fatigue,
    String title = 'Muscle Fatigue',
    bool showPeriodSelector = false,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return HomePageViewData(
      greeting: 'Hello, Marin!',
      weekRangeLabel: 'AUG 03 — AUG 09',
      nutrition: const HomeMacroStripViewData(
        calories: 2792,
        proteinGrams: 155,
        carbsGrams: 30,
        fatsGrams: 228,
      ),
      progress: HomeProgressCardViewData(
        title: title,
        selectedPeriod: TimePeriod.month,
        selectorEnabled: true,
        showPeriodSelector: showPeriodSelector,
        muscleMapMode: mode,
        bodyVisual: HomeBodyVisualViewData(
          frontLayers: <HomeBodyOverlayViewData>[
            HomeBodyOverlayViewData(
              assetPath: 'assets/images/body/front_chest.png',
              color: LiftColors.fatigue[4],
              opacity: 0.94,
              label: 'Chest',
            ),
          ],
          backLayers: const <HomeBodyOverlayViewData>[],
          subtitle: 'Current fatigue level',
        ),
        muscleSummary: <HomeMuscleSummaryItemViewData>[
          HomeMuscleSummaryItemViewData(
            displayName: 'Chest',
            stimulusLabel: '20',
            intensityLabel: 'Maximum',
            color: LiftColors.fatigue[4],
          ),
        ],
        isLoading: isLoading,
        errorMessage: errorMessage,
      ),
    );
  }

  Widget buildSubject({
    HomePageViewData? viewData,
    ValueChanged<MuscleMapMode>? onModeChanged,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return AppShell(
      home: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: HomeContent(
                viewData: viewData ?? buildViewData(),
                onRefresh: () async {},
                onPeriodChanged: (TimePeriod _) {},
                onRetryVisuals: () {},
                onModeChanged: onModeChanged ?? (MuscleMapMode _) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nth `Container` ancestor of [text], closest first. The mode toggle is a
  /// private widget, so its two boxes (segment, then outer frame) are reached
  /// through the ancestor chain rather than by type.
  Container containerAbove(WidgetTester tester, String text, int index) {
    return tester
        .widgetList<Container>(
          find.ancestor(of: find.text(text), matching: find.byType(Container)),
        )
        .elementAt(index);
  }

  group('HomeContent', () {
    testWidgets('the week range sits above the greeting', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final double rangeTop = tester
          .getTopLeft(find.text('AUG 03 — AUG 09'))
          .dy;
      final double greetingTop = tester
          .getTopLeft(find.text('Hello, Marin!'))
          .dy;

      expect(rangeTop, lessThan(greetingTop));
    });

    testWidgets('nothing on Home is a Card', (WidgetTester tester) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('intake values render through LiftNumber', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // Three, not four: KCAL is a spaced label beneath its number, so the
      // calorie value is a plain mono `Text`, not a glued-unit `LiftNumber`.
      expect(find.byType(LiftNumber), findsNWidgets(3));
      expect(find.text('2792'), findsOneWidget);
      expect(find.text('155g'), findsOneWidget);
      expect(find.text('30g'), findsOneWidget);
      expect(find.text('228g'), findsOneWidget);
    });

    testWidgets('the KCAL value carries the tabular data font features', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // Its three `LiftNumber` siblings get these for free; this one is a
      // bare `Text` and has to ask.
      expect(
        tester.widget<Text>(find.text('2792')).style?.fontFeatures,
        LiftText.dataFeatures,
      );
    });

    testWidgets('a four-digit calorie value stays on one line at 1.3x text', (
      WidgetTester tester,
    ) async {
      // Each intake column is an `Expanded` — 80dp of the 320dp content
      // width — so without something pinning the value to one line, `2792`
      // wraps here and reads on screen as two different numbers.
      await pumpAtPhoneWidth(
        tester,
        buildSubject(textScaler: const TextScaler.linear(1.3)),
      );

      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text('2792'),
      );
      // One box per line: `getBoxesForSelection` splits the selection at
      // every line break, so counting distinct box tops counts lines.
      final Set<double> lineTops = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          )
          .map((ui.TextBox box) => box.top)
          .toSet();

      expect(
        lineTops,
        hasLength(1),
        reason: 'a calorie count broken across two lines reads as two numbers',
      );
      expectNoOverflow(tester);
    });

    testWidgets('the four intake labels are mono caps', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('KCAL'), findsOneWidget);
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FATS'), findsOneWidget);

      final TextStyle? style = tester.widget<Text>(find.text('PROTEIN')).style;
      expect(style?.fontFamily, 'JetBrainsMono');
      expect(style?.color, LiftColors.textDim);
    });

    testWidgets('the muscle summary rows are gone', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('Chest'), findsNothing);
      expect(find.textContaining('Maximum'), findsNothing);
    });

    testWidgets('the mode toggle is square, filled and iconless', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('VOLUME'), findsOneWidget);
      expect(find.text('FATIGUE'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(HomePageKeys.progressCardKey),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      final Container selectedSegment = containerAbove(tester, 'FATIGUE', 0);
      final Container unselectedSegment = containerAbove(tester, 'VOLUME', 0);
      expect(selectedSegment.color, LiftColors.actionFill);
      expect(unselectedSegment.color, Colors.transparent);
      // A `color:` argument and a `decoration:` are mutually exclusive on
      // `Container`, so a null decoration is proof the segment has no radius.
      expect(selectedSegment.decoration, isNull);
      expect(unselectedSegment.decoration, isNull);

      expect(
        tester.widget<Text>(find.text('FATIGUE')).style?.color,
        Colors.white,
      );
      expect(
        tester.widget<Text>(find.text('VOLUME')).style?.color,
        LiftColors.textSecondary,
      );

      final Container frame = containerAbove(tester, 'VOLUME', 1);
      final BoxDecoration frameDecoration = frame.decoration! as BoxDecoration;
      expect(frameDecoration.borderRadius, isNull);
      expect(frameDecoration.color, LiftColors.surface);
    });

    testWidgets('tapping a toggle segment reports the new mode', (
      WidgetTester tester,
    ) async {
      MuscleMapMode? reported;
      await pumpAtPhoneWidth(
        tester,
        buildSubject(onModeChanged: (MuscleMapMode mode) => reported = mode),
      );

      // Fatigue is the selected mode, so VOLUME is the segment that changes
      // anything when tapped.
      await tester.tap(find.text('VOLUME'));
      await tester.pump();

      expect(reported, MuscleMapMode.volume);
    });

    testWidgets('the section title takes all the width the toggle leaves', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // A `Flexible` title beside a `Spacer` is two flex children of factor
      // 1, so `RenderFlex` splits the free width evenly and the title gets
      // half the room it should — enough to ellipsize `MUSCLE FATIGUE`. The
      // invariant a single `Expanded` establishes is that the title box and
      // the toggle together account for the whole heading row, with nothing
      // parked in a spacer.
      //
      // This is asserted as a width identity rather than as "the title does
      // not ellipsize": the test harness falls back to a font far wider than
      // JetBrainsMono, so an absolute width threshold would encode the
      // harness's metrics rather than the layout's behaviour.
      final Finder titleFinder = find.text('MUSCLE FATIGUE');
      final double titleWidth = tester.getSize(titleFinder).width;
      final double headingRowWidth = tester
          .getSize(
            find.ancestor(of: titleFinder, matching: find.byType(Row)).first,
          )
          .width;
      final double toggleWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.text('VOLUME'),
                  matching: find.byType(Container),
                )
                .at(1),
          )
          .width;

      expect(
        titleWidth,
        moreOrLessEquals(headingRowWidth - toggleWidth, epsilon: 0.5),
      );
    });

    testWidgets('both section rules are full-bleed', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Size headerRule = tester.getSize(
        find.byKey(HomePageKeys.headerRuleKey),
      );
      final Size intakeRule = tester.getSize(
        find.byKey(HomePageKeys.intakeRuleKey),
      );

      expect(headerRule.width, 360);
      expect(headerRule.height, LiftShape.borderWidth);
      expect(intakeRule.width, 360);
      expect(intakeRule.height, LiftShape.borderWidth);
    });

    testWidgets('the muscle map fills the space left over and the page fits', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // `maxScrollExtent == 0` is a *shape* guard, not a fit guard: it is
      // structurally true whenever the scroll child is `SizedBox(height:
      // viewport)`, even if the column inside overflows — a zero-height
      // scroll extent says nothing about whether the content fit. It stays
      // meaningful here only because `640` (the floor `home_content.dart`
      // now falls back to when the chrome grows) is below `800`, the
      // default `phone_viewport.dart` harness height asserted by
      // `lessThan(800)` below — so at this harness size the scroll child is
      // still exactly viewport-tall. The actual "the page fits" guarantee —
      // that nothing overflows — comes from `expectNoOverflow` in the
      // separate 'home renders without overflow at phone width' test (and,
      // on a viewport shorter than the floor, from 'scrolls instead of
      // overflowing on a short viewport'). Do not read more into this
      // assertion than that nothing reintroduced an intrinsic- or
      // list-based layout.
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomePageKeys.refreshListKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, 0);

      // The intake block — the last thing on the page — is inside the viewport.
      expect(tester.getBottomLeft(find.text('KCAL')).dy, lessThan(800));

      // The panel takes the slack rather than a fixed or intrinsic height.
      final double panelHeight = tester
          .getSize(find.byKey(HomePageKeys.bodyVisualPanelKey))
          .height;
      expect(panelHeight, greaterThan(300));
      expect(panelHeight, lessThan(600));
    });

    testWidgets('home renders without overflow at phone width', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expectNoOverflow(tester);
    });

    testWidgets('scrolls instead of overflowing on a short viewport', (
      WidgetTester tester,
    ) async {
      // 360x430 logical. The page is bounded to the viewport so the muscle
      // map can be `Expanded`, but `Expanded` floors at zero rather than at
      // something readable — so when the fixed chrome no longer fits, the
      // scroll child has to outgrow the viewport and scroll instead of
      // overflowing. That is what `_minPageHeight` in `home_content.dart`
      // buys, and this is the case that proves it: the pre-floor shape
      // overflowed here by 12px with a scroll extent still pinned at 0.
      //
      // A large `textScaler` is the other way in, and it is deliberately
      // NOT used: under the test harness's fallback font the mode toggle
      // measures ~201dp against roughly 136dp with the real JetBrainsMono,
      // so at 2x the harness overflows the heading row while the shipped
      // toggle (~282dp) still fits the 320dp content width. A text-scale
      // assertion here would measure the harness's font metrics rather than
      // this layout.
      await pumpAtPhoneWidth(
        tester,
        buildSubject(),
        physicalSize: const Size(1080, 1290),
      );

      expectNoOverflow(tester);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(HomePageKeys.refreshListKey),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });
  });
}
