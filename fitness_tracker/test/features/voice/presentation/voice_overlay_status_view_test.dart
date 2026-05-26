import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/features/voice/application/voice_bloc.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_overlay_keys.dart';
import 'package:fitness_tracker/features/voice/presentation/widgets/voice_overlay_status_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap({
  required VoiceStatus status,
  bool isWorkoutModeActive = false,
  VoidCallback? onMicTap,
  VoidCallback? onStopListening,
  VoidCallback? onInterrupt,
  VoidCallback? onRetry,
  VoidCallback? onWorkoutModeToggle,
}) {
  return MaterialApp(
    home: Scaffold(
      body: VoiceOverlayStatusView(
        status: status,
        isWorkoutModeActive: isWorkoutModeActive,
        onMicTap: onMicTap ?? () {},
        onStopListening: onStopListening ?? () {},
        onInterrupt: onInterrupt ?? () {},
        onRetry: onRetry ?? () {},
        onWorkoutModeToggle: onWorkoutModeToggle ?? () {},
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VoiceOverlayStatusView', () {
    group('idle', () {
      testWidgets('shows idle hint text', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.idle));
        expect(find.text(AppStrings.voiceOverlayHintIdle), findsOneWidget);
      });

      testWidgets('shows mic button', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.idle));
        expect(find.byKey(VoiceOverlayKeys.micButtonKey), findsOneWidget);
      });

      testWidgets('mic button fires onMicTap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _wrap(status: VoiceStatus.idle, onMicTap: () => tapped = true),
        );
        await tester.tap(find.byKey(VoiceOverlayKeys.micButtonKey));
        expect(tapped, isTrue);
      });
    });

    group('listening', () {
      testWidgets('shows listening hint text', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.listening));
        expect(find.text(AppStrings.voiceOverlayHintListening), findsOneWidget);
      });

      testWidgets('shows mic button (active) and stop button', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.listening));
        expect(find.byKey(VoiceOverlayKeys.micButtonKey), findsOneWidget);
        expect(find.byKey(VoiceOverlayKeys.stopButtonKey), findsOneWidget);
      });

      testWidgets('stop button fires onStopListening', (tester) async {
        var stopped = false;
        await tester.pumpWidget(
          _wrap(
            status: VoiceStatus.listening,
            onStopListening: () => stopped = true,
          ),
        );
        await tester.tap(find.byKey(VoiceOverlayKeys.stopButtonKey));
        expect(stopped, isTrue);
      });
    });

    group('transcribing / thinking', () {
      testWidgets('transcribing shows processing hint', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.transcribing));
        expect(
          find.text(AppStrings.voiceOverlayHintTranscribing),
          findsOneWidget,
        );
      });

      testWidgets('thinking shows thinking hint', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.thinking));
        expect(find.text(AppStrings.voiceOverlayHintThinking), findsOneWidget);
      });

      testWidgets('no mic or stop button while thinking', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.thinking));
        expect(find.byKey(VoiceOverlayKeys.micButtonKey), findsNothing);
        expect(find.byKey(VoiceOverlayKeys.stopButtonKey), findsNothing);
      });
    });

    group('speaking', () {
      testWidgets('shows speaking hint text', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.speaking));
        expect(find.text(AppStrings.voiceOverlayHintSpeaking), findsOneWidget);
      });

      testWidgets('shows interrupt button', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.speaking));
        expect(find.byKey(VoiceOverlayKeys.interruptButtonKey), findsOneWidget);
      });

      testWidgets('interrupt button fires onInterrupt', (tester) async {
        var interrupted = false;
        await tester.pumpWidget(
          _wrap(
            status: VoiceStatus.speaking,
            onInterrupt: () => interrupted = true,
          ),
        );
        await tester.tap(find.byKey(VoiceOverlayKeys.interruptButtonKey));
        expect(interrupted, isTrue);
      });
    });

    group('error', () {
      testWidgets('shows retry hint text', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.error));
        expect(find.text(AppStrings.voiceOverlayRetry), findsWidgets);
      });

      testWidgets('shows retry button', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.error));
        expect(find.byKey(VoiceOverlayKeys.retryButtonKey), findsOneWidget);
      });

      testWidgets('retry button fires onRetry', (tester) async {
        var retried = false;
        await tester.pumpWidget(
          _wrap(status: VoiceStatus.error, onRetry: () => retried = true),
        );
        await tester.tap(find.byKey(VoiceOverlayKeys.retryButtonKey));
        expect(retried, isTrue);
      });
    });

    group('workout mode row', () {
      testWidgets('shows workout mode label', (tester) async {
        await tester.pumpWidget(_wrap(status: VoiceStatus.idle));
        expect(
          find.text(AppStrings.voiceOverlayWorkoutModeLabel),
          findsOneWidget,
        );
      });

      testWidgets('workout mode toggle fires onWorkoutModeToggle', (
        tester,
      ) async {
        var toggled = false;
        await tester.pumpWidget(
          _wrap(
            status: VoiceStatus.idle,
            onWorkoutModeToggle: () => toggled = true,
          ),
        );
        await tester.tap(find.byKey(VoiceOverlayKeys.workoutModeToggleKey));
        expect(toggled, isTrue);
      });
    });
  });
}
