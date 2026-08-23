import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/library_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/phone_viewport.dart';

void main() {
  group('LibraryListRow', () {
    Widget buildSubject({
      String? secondaryMeta,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      return MaterialApp(
        theme: LiftTheme.dark(),
        home: Scaffold(
          // Column, not a bare body: a Scaffold body stretches its child to
          // the full viewport height, which would make the row's own height
          // unmeasurable.
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LibraryListRow(
                title: 'Bench Press',
                meta: 'CHEST · TRICEPS · SHOULDERS',
                secondaryMeta: secondaryMeta,
                onTap: onTap ?? () {},
                onLongPress: onLongPress ?? () {},
                editHint: 'Edit exercise',
                deleteHint: 'Delete exercise',
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders the name over the mono meta line', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Text name = tester.widget<Text>(find.text('Bench Press'));
      expect(name.style!.fontFamily, 'SpaceGrotesk');
      expect(name.style!.fontSize, LiftText.titleMedium.fontSize);
      expect(name.style!.color, LiftColors.textPrimary);

      final Text meta = tester.widget<Text>(
        find.text('CHEST · TRICEPS · SHOULDERS'),
      );
      expect(meta.style!.fontFamily, 'JetBrainsMono');
      expect(meta.style!.color, LiftColors.textDim);

      expectNoOverflow(tester);
    });

    testWidgets('the row is a rule, not a card — one hairline, no radius', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.byType(Card), findsNothing);

      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(LibraryListRow),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNull);
      expect(decoration.border!.bottom.color, LiftColors.hairline);
      expect(decoration.border!.top, BorderSide.none);
    });

    testWidgets('frame 11 puts consecutive rules 63dp apart', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // 13.5 + 18 (titleMedium at 1.2) + 3 + 12.54 (labelMedium) + 13.5 + 1.
      expect(
        tester.getSize(find.byType(LibraryListRow)).height,
        closeTo(63, 1),
      );
    });

    testWidgets('a meal row carries a second, fainter mono line', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(secondaryMeta: '21P · 22C · 49F'),
      );

      final Text macros = tester.widget<Text>(find.text('21P · 22C · 49F'));
      expect(macros.style!.fontFamily, 'JetBrainsMono');
      expect(macros.style!.color, LiftColors.textFaint);
    });

    testWidgets('tap edits and long-press deletes', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      int longPresses = 0;
      await pumpAtPhoneWidth(
        tester,
        buildSubject(onTap: () => taps++, onLongPress: () => longPresses++),
      );

      await tester.tap(find.byType(LibraryListRow));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.longPress(find.byType(LibraryListRow));
      await tester.pumpAndSettle();
      expect(longPresses, 1);
    });

    testWidgets('both re-homed actions are published as semantics actions', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpAtPhoneWidth(tester, buildSubject());

      final SemanticsNode node = tester.getSemantics(
        find.byType(LibraryListRow),
      );
      final Iterable<String?> labels = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map((int id) => CustomSemanticsAction.getAction(id)!.label);

      expect(labels, containsAll(<String>['Edit exercise', 'Delete exercise']));
      handle.dispose();
    });
  });

  group('LibraryFilterChip', () {
    testWidgets('sizes to its label rather than filling the row', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        MaterialApp(
          theme: LiftTheme.dark(),
          home: Scaffold(
            body: Wrap(
              children: <Widget>[
                LibraryFilterChip(
                  label: 'Chest',
                  selected: false,
                  onTap: () {},
                ),
                LibraryFilterChip(
                  label: 'Shoulders',
                  selected: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final double chest = tester
          .getSize(find.widgetWithText(LibraryFilterChip, 'CHEST'))
          .width;
      final double shoulders = tester
          .getSize(find.widgetWithText(LibraryFilterChip, 'SHOULDERS'))
          .width;

      expect(
        chest,
        lessThan(shoulders),
        reason:
            'a Container with `alignment` expands to the incoming '
            'constraints, which inside a Wrap gives every chip the full row',
      );
      expect(chest, lessThan(360));
    });

    testWidgets('is 28dp tall by default and 30 when the dialog asks', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        MaterialApp(
          theme: LiftTheme.dark(),
          home: Scaffold(
            body: Wrap(
              children: <Widget>[
                LibraryFilterChip(
                  label: 'Chest',
                  selected: false,
                  onTap: () {},
                ),
                LibraryFilterChip(
                  label: 'Back',
                  selected: false,
                  height: 30,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.widgetWithText(LibraryFilterChip, 'CHEST')).height,
        28,
      );
      expect(
        tester.getSize(find.widgetWithText(LibraryFilterChip, 'BACK')).height,
        30,
      );
    });
  });

  group('LibraryAddButton', () {
    testWidgets('is a compact filled button that matches the field height', (
      WidgetTester tester,
    ) async {
      bool pressed = false;
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpAtPhoneWidth(
        tester,
        MaterialApp(
          theme: LiftTheme.dark(),
          home: Scaffold(
            body: LibraryBrowseBar(
              searchField: LibrarySearchField(
                controller: controller,
                hintText: 'Search exercises',
                onChanged: (_) {},
                onClear: () {},
              ),
              addButton: LibraryAddButton(
                semanticLabel: 'Add exercise',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      // The label is the short form — what is being added is named by the tab
      // strip above it, and the long form is on the semantics node.
      expect(find.text('+ ADD'), findsOneWidget);
      expect(find.text('+ ADD EXERCISE'), findsNothing);

      final Size button = tester.getSize(find.byType(LibraryAddButton));
      final Size field = tester.getSize(find.byType(LibrarySearchField));
      expect(button.height, field.height);
      // The button's own floor lifts the whole row to a legal tap target.
      expect(button.height, greaterThanOrEqualTo(44));
      // Compact: the old full-width dock spanned the whole 320dp row.
      expect(button.width, lessThan(160));

      await tester.tap(find.byType(LibraryAddButton));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
      expectNoOverflow(tester);
    });

    testWidgets('is activatable from assistive technology by its long name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpAtPhoneWidth(
        tester,
        MaterialApp(
          theme: LiftTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: LibraryAddButton(
                semanticLabel: 'Add exercise',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(LibraryAddButton),
      );
      expect(node.label, 'Add exercise');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('LibraryFilterChip', () {
    testWidgets('a chip is activatable from assistive technology', (
      tester,
    ) async {
      // `excludeSemantics: true` drops the GestureDetector's own tap action,
      // so the wrapping node has to publish one or the filter row announces
      // as buttons a screen reader cannot press.
      final SemanticsHandle handle = tester.ensureSemantics();

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: LiftTheme.dark(),
          home: Scaffold(
            body: LibraryFilterChip(
              label: 'Chest',
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SemanticsNode node = tester.getSemantics(
        find.byType(LibraryFilterChip),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      handle.dispose();
    });
  });
}
