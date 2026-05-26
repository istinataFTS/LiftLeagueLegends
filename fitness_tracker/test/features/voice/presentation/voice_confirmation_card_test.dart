import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/voice_tool_call.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_overlay_keys.dart';
import 'package:fitness_tracker/features/voice/presentation/widgets/voice_confirmation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _stubToolCall = VoiceToolCall(
  id: 'call_test_001',
  toolName: 'logWorkoutSet',
  displaySummary: 'Log: Bench Press — 80 kg × 10 reps',
  args: <String, dynamic>{
    'exercise_name': 'Bench Press',
    'weight': 80.0,
    'reps': 10,
  },
);

Widget _wrap({
  VoiceToolCall toolCall = _stubToolCall,
  VoidCallback? onConfirm,
  VoidCallback? onEdit,
  VoidCallback? onCancel,
}) {
  return MaterialApp(
    home: Scaffold(
      body: VoiceConfirmationCard(
        toolCall: toolCall,
        onConfirm: onConfirm ?? () {},
        onEdit: onEdit ?? () {},
        onCancel: onCancel ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VoiceConfirmationCard', () {
    group('rendering', () {
      testWidgets('shows the confirmation card container', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(
          find.byKey(VoiceOverlayKeys.confirmationCardKey),
          findsOneWidget,
        );
      });

      testWidgets('shows the action label', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(AppStrings.voiceConfirmActionLabel), findsOneWidget);
      });

      testWidgets('shows toolCall.displaySummary', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(_stubToolCall.displaySummary), findsOneWidget);
      });

      testWidgets('shows Yes, Edit and Cancel buttons', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.byKey(VoiceOverlayKeys.confirmationYesKey), findsOneWidget);
        expect(
          find.byKey(VoiceOverlayKeys.confirmationEditKey),
          findsOneWidget,
        );
        expect(
          find.byKey(VoiceOverlayKeys.confirmationCancelKey),
          findsOneWidget,
        );
      });

      testWidgets('Yes button label matches AppStrings', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(AppStrings.voiceConfirmYes), findsOneWidget);
      });

      testWidgets('Edit button label matches AppStrings', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(AppStrings.voiceConfirmEdit), findsOneWidget);
      });

      testWidgets('Cancel button label matches AppStrings', (tester) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(AppStrings.voiceConfirmCancel), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping Yes fires onConfirm', (tester) async {
        var confirmed = false;
        await tester.pumpWidget(_wrap(onConfirm: () => confirmed = true));
        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationYesKey));
        expect(confirmed, isTrue);
      });

      testWidgets('tapping Edit fires onEdit', (tester) async {
        var edited = false;
        await tester.pumpWidget(_wrap(onEdit: () => edited = true));
        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationEditKey));
        expect(edited, isTrue);
      });

      testWidgets('tapping Cancel fires onCancel', (tester) async {
        var cancelled = false;
        await tester.pumpWidget(_wrap(onCancel: () => cancelled = true));
        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationCancelKey));
        expect(cancelled, isTrue);
      });

      testWidgets('each button fires only its own callback', (tester) async {
        var confirmCount = 0;
        var editCount = 0;
        var cancelCount = 0;

        await tester.pumpWidget(
          _wrap(
            onConfirm: () => confirmCount++,
            onEdit: () => editCount++,
            onCancel: () => cancelCount++,
          ),
        );

        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationYesKey));
        expect(confirmCount, 1);
        expect(editCount, 0);
        expect(cancelCount, 0);

        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationEditKey));
        expect(confirmCount, 1);
        expect(editCount, 1);
        expect(cancelCount, 0);

        await tester.tap(find.byKey(VoiceOverlayKeys.confirmationCancelKey));
        expect(confirmCount, 1);
        expect(editCount, 1);
        expect(cancelCount, 1);
      });
    });

    group('content update', () {
      testWidgets('updates displaySummary when toolCall changes', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap());
        expect(find.text(_stubToolCall.displaySummary), findsOneWidget);

        const updated = VoiceToolCall(
          id: 'call_test_002',
          toolName: 'logNutrition',
          displaySummary: 'Log: Chicken Breast — 200 g',
          args: <String, dynamic>{'meal_name': 'Chicken Breast', 'grams': 200},
        );

        await tester.pumpWidget(_wrap(toolCall: updated));
        expect(find.text(updated.displaySummary), findsOneWidget);
        expect(find.text(_stubToolCall.displaySummary), findsNothing);
      });
    });
  });
}
