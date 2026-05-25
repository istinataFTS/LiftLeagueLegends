import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/network_status_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../../domain/entities/app_session.dart';
import '../../../domain/entities/voice_settings.dart' show WakeWordPreset;
import '../../../domain/services/voice_wake_word_service.dart';
import '../../../injection/injection_container.dart';
import '../application/voice_bloc.dart';
import 'voice_overlay_keys.dart';
import 'widgets/voice_budget_indicator.dart';
import 'widgets/voice_confirmation_card.dart';
import 'widgets/voice_overlay_status_view.dart';
import 'widgets/voice_transcript_list.dart';
import 'widgets/voice_workout_mode_banner.dart';

/// Full-screen voice overlay.
///
/// Scopes a fresh [VoiceBloc] instance (factory) and fires
/// [VoiceSessionStarted] on first build. Manages connectivity and
/// wake-word subscriptions for the duration the overlay is visible.
///
/// When [openedByWakeWord] is true (the overlay was opened by a Porcupine
/// detection, not by the user tapping the FAB), [VoiceListenRequested] is
/// dispatched on the first post-frame callback so STT starts automatically —
/// closing the first-fire gap where the user already spoke the wake word
/// and expects the assistant to be listening immediately.
class VoiceOverlayPage extends StatelessWidget {
  const VoiceOverlayPage({
    required this.session,
    this.openedByWakeWord = false,
    super.key,
  });

  final AppSession session;

  /// Whether this overlay was triggered by a wake-word detection (vs. a
  /// manual FAB tap). When true, STT starts automatically on first frame.
  final bool openedByWakeWord;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VoiceBloc>(
      create: (_) => sl<VoiceBloc>()..add(VoiceSessionStarted(session)),
      child: _VoiceOverlayView(
        session: session,
        openedByWakeWord: openedByWakeWord,
      ),
    );
  }
}

class _VoiceOverlayView extends StatefulWidget {
  const _VoiceOverlayView({
    required this.session,
    required this.openedByWakeWord,
  });

  final AppSession session;
  final bool openedByWakeWord;

  @override
  State<_VoiceOverlayView> createState() => _VoiceOverlayViewState();
}

class _VoiceOverlayViewState extends State<_VoiceOverlayView> {
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<WakeWordPreset>? _wakeWordSub;

  /// Non-null while the user is correcting a pending confirmation via the
  /// edit bar. Set to the [VoiceToolCall.displaySummary] when Edit is tapped;
  /// cleared on Send or Discard.
  String? _editPrefill;
  late final TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _checkInitialConnectivity();
    _subscribeToConnectivity();
    _subscribeToWakeWord();
    if (widget.openedByWakeWord) {
      // Auto-start STT on first frame: the user has already spoken the wake
      // word and expects the assistant to be listening immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<VoiceBloc>().add(const VoiceListenRequested());
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _wakeWordSub?.cancel();
    _editController.dispose();
    super.dispose();
  }

  // ── Connectivity ────────────────────────────────────────────────────────────

  Future<void> _checkInitialConnectivity() async {
    final isOnline = await sl<NetworkStatusService>().isNetworkAvailable();
    if (mounted) {
      context.read<VoiceBloc>().add(
        VoiceConnectivityChanged(isOnline: isOnline),
      );
    }
  }

  void _subscribeToConnectivity() {
    _connectivitySub = sl<NetworkStatusService>().onConnectivityChanged.listen((
      isOnline,
    ) {
      if (mounted) {
        context.read<VoiceBloc>().add(
          VoiceConnectivityChanged(isOnline: isOnline),
        );
      }
    });
  }

  // ── Wake-word re-trigger while overlay is open ──────────────────────────────

  void _subscribeToWakeWord() {
    _wakeWordSub = sl<VoiceWakeWordService>().onWakeWordDetected.listen((_) {
      if (!mounted) return;
      final bloc = context.read<VoiceBloc>();
      if (bloc.state.status == VoiceStatus.idle) {
        bloc.add(const VoiceListenRequested());
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceBloc, VoiceState>(
      builder: (context, state) {
        final VoiceBloc bloc = context.read<VoiceBloc>();

        return Scaffold(
          key: VoiceOverlayKeys.overlayPageKey,
          backgroundColor: AppTheme.backgroundDark,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                // ── Workout Mode banner (top, only when active) ──────────
                if (state.isWorkoutModeActive)
                  VoiceWorkoutModeBanner(
                    onToggle: () =>
                        bloc.add(const VoiceWorkoutModeToggled(active: false)),
                  ),

                // ── Header ───────────────────────────────────────────────
                _OverlayHeader(
                  onClose: () => Navigator.of(context).pop(),
                  onSettings: () => _openSettings(context),
                ),

                // ── Budget indicator ─────────────────────────────────────
                const VoiceBudgetIndicator(
                  key: VoiceOverlayKeys.budgetIndicatorKey,
                ),

                // ── Transcript + confirmation card ───────────────────────
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: VoiceTranscriptList(
                          messages: state.messages,
                          liveTranscript: state.status == VoiceStatus.listening
                              ? state.liveTranscript
                              : null,
                        ),
                      ),
                      if (state.pendingConfirmation != null)
                        VoiceConfirmationCard(
                          toolCall: state.pendingConfirmation!,
                          onConfirm: () =>
                              bloc.add(const VoiceConfirmationAccepted()),
                          onEdit: () {
                            final summary =
                                state.pendingConfirmation!.displaySummary;
                            setState(() {
                              _editPrefill = summary;
                              _editController
                                ..text = summary
                                ..selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: summary.length,
                                );
                            });
                            bloc.add(const VoiceConfirmationCancelled());
                          },
                          onCancel: () =>
                              bloc.add(const VoiceConfirmationCancelled()),
                        )
                      else if (_editPrefill != null)
                        _VoiceEditBar(
                          controller: _editController,
                          onSend: (text) {
                            final trimmed = text.trim();
                            if (trimmed.isEmpty) return;
                            setState(() => _editPrefill = null);
                            bloc.add(VoiceSendMessage(trimmed));
                          },
                          onDiscard: () => setState(() {
                            _editPrefill = null;
                            _editController.clear();
                          }),
                        ),
                    ],
                  ),
                ),

                // ── Status / action panel ─────────────────────────────────
                VoiceOverlayStatusView(
                  status: state.status,
                  isWorkoutModeActive: state.isWorkoutModeActive,
                  onMicTap: () => state.status == VoiceStatus.idle
                      ? bloc.add(const VoiceListenRequested())
                      : null,
                  onStopListening: () =>
                      bloc.add(const VoiceListenStopRequested()),
                  onInterrupt: () => bloc.add(const VoiceListenStopRequested()),
                  onRetry: () => bloc.add(const VoiceListenRequested()),
                  onWorkoutModeToggle: () => bloc.add(
                    VoiceWorkoutModeToggled(active: !state.isWorkoutModeActive),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSettings(BuildContext context) {
    // VoiceSettingsCubit is provided at the auth-session shell level —
    // pushed routes resolve it via `context.read` without a nested
    // BlocProvider.
    Navigator.of(context).pushNamed(AppRoutes.voiceSettings);
  }
}

// ---------------------------------------------------------------------------
// Edit bar
// ---------------------------------------------------------------------------

/// Inline text field shown after the user taps "Edit" on a confirmation card.
///
/// Pre-populated with the parsed [VoiceToolCall.displaySummary] so the user
/// can correct numbers or details before re-submitting to the voice bot.
/// [onSend] fires with the trimmed text; [onDiscard] closes the bar.
class _VoiceEditBar extends StatelessWidget {
  const _VoiceEditBar({
    required this.controller,
    required this.onSend,
    required this.onDiscard,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: VoiceOverlayKeys.editBarKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMedium,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: VoiceOverlayKeys.editBarFieldKey,
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textLight, fontSize: 15),
              decoration: const InputDecoration(
                hintText: AppStrings.voiceEditBarHint,
                hintStyle: TextStyle(color: AppTheme.textDim),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
            ),
          ),
          IconButton(
            key: VoiceOverlayKeys.editBarDiscardKey,
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.textDim,
            tooltip: AppStrings.voiceEditBarDiscard,
            onPressed: onDiscard,
          ),
          IconButton(
            key: VoiceOverlayKeys.editBarSendKey,
            icon: const Icon(Icons.send_rounded),
            color: AppTheme.primaryOrange,
            tooltip: AppStrings.voiceEditBarSend,
            onPressed: () => onSend(controller.text),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _OverlayHeader extends StatelessWidget {
  const _OverlayHeader({required this.onClose, required this.onSettings});

  final VoidCallback onClose;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            key: VoiceOverlayKeys.closeButtonKey,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: AppTheme.textMedium,
            onPressed: onClose,
            tooltip: AppStrings.close,
          ),
          const Expanded(
            child: Text(
              AppStrings.voiceOverlayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            key: VoiceOverlayKeys.settingsButtonKey,
            icon: const Icon(Icons.tune_rounded),
            color: AppTheme.textMedium,
            onPressed: onSettings,
            tooltip: AppStrings.voiceSettingsPageTitle,
          ),
        ],
      ),
    );
  }
}
