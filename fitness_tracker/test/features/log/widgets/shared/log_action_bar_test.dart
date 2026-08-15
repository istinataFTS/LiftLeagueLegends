import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    String ctaLabel = 'Log set',
    IconData ctaIcon = Icons.add_circle,
    VoidCallback? onSubmit,
    Widget? previewSlot,
    Widget? statusLine,
    bool canSubmit = true,
    bool isLoading = false,
  }) {
    return AppShell(
      home: Scaffold(
        body: LogActionBar(
          ctaLabel: ctaLabel,
          ctaIcon: ctaIcon,
          onSubmit: onSubmit ?? () {},
          previewSlot: previewSlot,
          statusLine: statusLine,
          canSubmit: canSubmit,
          isLoading: isLoading,
        ),
      ),
    );
  }

  group('LogActionBar', () {
    testWidgets('renders the CTA label', (tester) async {
      await tester.pumpWidget(buildSubject(ctaLabel: 'Log set'));
      await tester.pumpAndSettle();

      // The CTA label renders mono-caps uppercase (LiftText.labelLarge).
      expect(find.text('LOG SET'), findsOneWidget);
    });

    testWidgets('renders the CTA icon', (tester) async {
      await tester.pumpWidget(buildSubject(ctaIcon: Icons.fitness_center));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    testWidgets('shows preview slot widget when provided', (tester) async {
      await tester.pumpWidget(
        buildSubject(previewSlot: const Text('preview-content')),
      );
      await tester.pumpAndSettle();

      expect(find.text('preview-content'), findsOneWidget);
    });

    testWidgets('hides preview slot when null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('preview-content'), findsNothing);
    });

    testWidgets('shows status line when provided', (tester) async {
      await tester.pumpWidget(
        buildSubject(statusLine: const Text('Logged ×3 today')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Logged ×3 today'), findsOneWidget);
    });

    testWidgets('hides status line when null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Logged ×3 today'), findsNothing);
    });

    testWidgets('tapping CTA calls onSubmit when canSubmit is true', (
      tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(
        buildSubject(canSubmit: true, onSubmit: () => called = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('LOG SET'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('tapping CTA does nothing when canSubmit is false', (
      tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(
        buildSubject(canSubmit: false, onSubmit: () => called = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('LOG SET'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });

    testWidgets('tapping CTA does nothing when isLoading is true', (
      tester,
    ) async {
      bool called = false;
      await tester.pumpWidget(
        buildSubject(
          canSubmit: true,
          isLoading: true,
          onSubmit: () => called = true,
        ),
      );
      // CircularProgressIndicator animates forever — use pump() not pumpAndSettle().
      await tester.pump();

      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('shows spinner instead of label when isLoading', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isLoading: true));
      // CircularProgressIndicator animates forever — use pump() not pumpAndSettle().
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('LOG SET'), findsNothing);
    });

    testWidgets('renders with custom label', (tester) async {
      await tester.pumpWidget(buildSubject(ctaLabel: 'Log meal'));
      await tester.pumpAndSettle();

      expect(find.text('LOG MEAL'), findsOneWidget);
    });

    testWidgets(
      "resolves the enabled button's painted fill to LiftColors.actionFill",
      (tester) async {
        await tester.pumpWidget(buildSubject(canSubmit: true));
        await tester.pumpAndSettle();

        // The enabled CTA passes no local `style` — it defers entirely to
        // `LiftTheme.dark().elevatedButtonTheme`. Read the actually-painted
        // `Material.color` rather than re-deriving the resolved ButtonStyle,
        // so this genuinely exercises the theme rather than restating a
        // colour the widget hard-coded.
        final ElevatedButton button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(
          button.style,
          isNull,
          reason:
              'enabled CTA must defer to the theme default, not a local '
              'style override',
        );

        final Material material = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(ElevatedButton),
                matching: find.byType(Material),
              ),
            )
            .first;
        expect(material.color, LiftColors.actionFill);
      },
    );

    testWidgets(
      'resolves the disabled button to a transparent, bordered outline',
      (tester) async {
        await tester.pumpWidget(buildSubject(canSubmit: false));
        await tester.pumpAndSettle();

        final Material material = tester
            .widgetList<Material>(
              find.descendant(
                of: find.byType(ElevatedButton),
                matching: find.byType(Material),
              ),
            )
            .first;
        expect(material.color, Colors.transparent);

        final RoundedRectangleBorder shape =
            material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, LiftColors.border);
        expect(shape.side.width, LiftShape.borderWidth);
      },
    );

    testWidgets('the footnote status line renders in the mono label style', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(statusLine: const Text('Logged ×3 today')),
      );
      await tester.pumpAndSettle();

      final DefaultTextStyle footnote = tester.widget<DefaultTextStyle>(
        find.byKey(const ValueKey<String>('log-action-bar-footnote')),
      );
      expect(footnote.style.fontFamily, 'JetBrainsMono');
      expect(footnote.style.color, LiftColors.textDim);
    });
  });
}
