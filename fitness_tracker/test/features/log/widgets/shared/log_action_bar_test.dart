import 'package:fitness_tracker/app/app.dart';
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

      expect(find.text('Log set'), findsOneWidget);
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

      await tester.tap(find.text('Log set'));
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

      await tester.tap(find.text('Log set'));
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
      expect(find.text('Log set'), findsNothing);
    });

    testWidgets('renders with custom label', (tester) async {
      await tester.pumpWidget(buildSubject(ctaLabel: 'Log meal'));
      await tester.pumpAndSettle();

      expect(find.text('Log meal'), findsOneWidget);
    });
  });
}
