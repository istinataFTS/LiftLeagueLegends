import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../application/voice_bloc.dart';
import '../voice_overlay_keys.dart';

/// Bottom panel of the voice overlay — adapts to each [VoiceStatus].
///
/// The panel is purely presentational. The parent ([VoiceOverlayPage])
/// attaches all callbacks and reads state from [VoiceBloc].
class VoiceOverlayStatusView extends StatelessWidget {
  const VoiceOverlayStatusView({
    required this.status,
    required this.isWorkoutModeActive,
    required this.onMicTap,
    required this.onStopListening,
    required this.onInterrupt,
    required this.onRetry,
    required this.onWorkoutModeToggle,
    super.key,
  });

  final VoiceStatus status;
  final bool isWorkoutModeActive;

  final VoidCallback onMicTap;
  final VoidCallback onStopListening;
  final VoidCallback onInterrupt;
  final VoidCallback onRetry;
  final VoidCallback onWorkoutModeToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: VoiceOverlayKeys.statusViewKey,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _HintText(status: status),
          const SizedBox(height: 20),
          _ActionRow(
            status: status,
            onMicTap: onMicTap,
            onStopListening: onStopListening,
            onInterrupt: onInterrupt,
            onRetry: onRetry,
          ),
          const SizedBox(height: 16),
          _WorkoutModeRow(
            isActive: isWorkoutModeActive,
            onToggle: onWorkoutModeToggle,
          ),
        ],
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.status});

  final VoiceStatus status;

  String get _hint {
    switch (status) {
      case VoiceStatus.idle:
      case VoiceStatus.awaitingConfirmation:
        // While a confirmation card is showing, the card itself prompts the
        // user; the hint stays on the neutral idle copy so we don't shout
        // "confirm or cancel" twice.
        return AppStrings.voiceOverlayHintIdle;
      case VoiceStatus.listening:
        return AppStrings.voiceOverlayHintListening;
      case VoiceStatus.transcribing:
        return AppStrings.voiceOverlayHintTranscribing;
      case VoiceStatus.thinking:
        return AppStrings.voiceOverlayHintThinking;
      case VoiceStatus.speaking:
        return AppStrings.voiceOverlayHintSpeaking;
      case VoiceStatus.error:
        return AppStrings.voiceOverlayRetry;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        _hint,
        key: ValueKey<VoiceStatus>(status),
        style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.status,
    required this.onMicTap,
    required this.onStopListening,
    required this.onInterrupt,
    required this.onRetry,
  });

  final VoiceStatus status;
  final VoidCallback onMicTap;
  final VoidCallback onStopListening;
  final VoidCallback onInterrupt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey<VoiceStatus>(status),
        child: _buildForStatus(),
      ),
    );
  }

  Widget _buildForStatus() {
    switch (status) {
      case VoiceStatus.idle:
      case VoiceStatus.awaitingConfirmation:
        // Confirmation card is visible above the status view; keep an
        // inactive mic button available so a verbal "cancel" still has
        // the engine warmed and the visual remains coherent.
        return _MicButton(
          key: VoiceOverlayKeys.micButtonKey,
          onTap: onMicTap,
          isActive: false,
        );

      case VoiceStatus.listening:
        return Column(
          children: <Widget>[
            _MicButton(
              key: VoiceOverlayKeys.micButtonKey,
              onTap: onMicTap,
              isActive: true,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: VoiceOverlayKeys.stopButtonKey,
              onPressed: onStopListening,
              icon: const Icon(Icons.stop_rounded, size: 16),
              label: const Text(AppStrings.voiceOverlayStopListening),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textMedium),
            ),
          ],
        );

      case VoiceStatus.transcribing:
      case VoiceStatus.thinking:
        return const _SpinnerButton();

      case VoiceStatus.speaking:
        return TextButton.icon(
          key: VoiceOverlayKeys.interruptButtonKey,
          onPressed: onInterrupt,
          icon: const Icon(Icons.pan_tool_rounded, size: 16),
          label: const Text(AppStrings.voiceOverlayInterrupt),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryOrange),
        );

      case VoiceStatus.error:
        return FilledButton.icon(
          key: VoiceOverlayKeys.retryButtonKey,
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(AppStrings.voiceOverlayRetry),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.surfaceLight,
            foregroundColor: AppTheme.textLight,
          ),
        );
    }
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onTap, required this.isActive, super.key});

  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppTheme.primaryOrange : AppTheme.surfaceMedium,
          border: Border.all(
            color: isActive ? AppTheme.primaryOrange : AppTheme.borderMedium,
            width: 2,
          ),
          boxShadow: isActive
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.primaryOrange.withAlpha(76),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: AppTheme.textLight,
          size: 32,
        ),
      ),
    );
  }
}

class _SpinnerButton extends StatelessWidget {
  const _SpinnerButton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 72,
      height: 72,
      child: Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryOrange,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class _WorkoutModeRow extends StatelessWidget {
  const _WorkoutModeRow({required this.isActive, required this.onToggle});

  final bool isActive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.fitness_center_rounded,
          size: 14,
          color: AppTheme.textDim,
        ),
        const SizedBox(width: 6),
        const Text(
          AppStrings.voiceOverlayWorkoutModeLabel,
          style: TextStyle(color: AppTheme.textDim, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Switch(
          key: VoiceOverlayKeys.workoutModeToggleKey,
          value: isActive,
          onChanged: (_) => onToggle(),
          activeThumbColor: AppTheme.primaryOrange,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
