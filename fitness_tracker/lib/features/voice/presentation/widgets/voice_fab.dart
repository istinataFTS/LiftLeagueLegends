import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/app_session.dart';
import '../../../../domain/entities/voice_settings.dart';
import '../../../../domain/services/voice_wake_word_service.dart';
import '../../../../injection/injection_container.dart';
import '../../application/voice_settings_cubit.dart';
import '../voice_overlay_keys.dart';
import '../voice_overlay_page.dart';

/// Persistent floating action button that opens the voice overlay and
/// manages the wake-word engine lifecycle.
///
/// Implements [WidgetsBindingObserver] so Porcupine is automatically stopped
/// when the app goes to the background (foreground-only mic policy) and
/// restarted on resume.
///
/// Guest users see the button disabled with a tooltip. Authenticated users
/// tap to open [VoiceOverlayPage].
class VoiceFab extends StatefulWidget {
  const VoiceFab({required this.session, super.key});

  final AppSession session;

  @override
  State<VoiceFab> createState() => _VoiceFabState();
}

class _VoiceFabState extends State<VoiceFab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  /// Wake-word service is a DI singleton (no `BlocProvider` for it).
  /// Captured once in [initState] so every method can reach it without
  /// repeated `sl<>` lookups. Allowed by the `widget-state-bloc-field`
  /// rule because the type does not end in `Bloc`/`Cubit`.
  late final VoiceWakeWordService _wakeWordService;

  StreamSubscription<WakeWordPreset>? _wakeWordSub;
  StreamSubscription<VoiceWakeWordException>? _wakeWordErrorSub;
  bool _overlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakeWordService = sl<VoiceWakeWordService>();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _listenToWakeWordStream();
    _listenToWakeWordErrors();
    _startWakeWordIfArmed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeWordSub?.cancel();
    _wakeWordErrorSub?.cancel();
    unawaited(_wakeWordService.stop());
    _pulseController.dispose();
    super.dispose();
  }

  // ── App lifecycle ───────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startWakeWordIfArmed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_wakeWordService.stop());
        _stopPulse();
    }
  }

  // ── Wake-word management ────────────────────────────────────────────────────

  void _startWakeWordIfArmed() {
    if (!mounted) return;
    final settings = context.read<VoiceSettingsCubit>().state;
    if (!settings.wakeWordArmedInForeground || widget.session.isGuest) return;
    _wakeWordService
        .start(settings.wakeWordPreset)
        .then((_) {
          if (mounted) _startPulse();
        })
        .catchError((Object e) {
          AppLogger.warning(
            'VoiceFab: failed to start wake word',
            error: e,
            category: 'voice',
          );
        });
  }

  void _listenToWakeWordStream() {
    _wakeWordSub = _wakeWordService.onWakeWordDetected.listen((_) {
      _onWakeWordFired();
    });
  }

  void _listenToWakeWordErrors() {
    _wakeWordErrorSub = _wakeWordService.onError.listen((e) {
      AppLogger.warning(
        'VoiceFab: wake word error: ${e.kind}',
        error: e,
        category: 'voice',
      );
    });
  }

  void _onWakeWordFired() {
    if (!mounted) return;
    if (_overlayOpen) return; // Overlay handles the listen trigger itself
    _openOverlay();
  }

  // ── Pulse animation ─────────────────────────────────────────────────────────

  void _startPulse() {
    if (!_pulseController.isAnimating) _pulseController.repeat();
  }

  void _stopPulse() {
    _pulseController.stop();
    _pulseController.reset();
  }

  // ── Overlay navigation ──────────────────────────────────────────────────────

  Future<void> _openOverlay() async {
    if (_overlayOpen || !mounted) return;
    setState(() => _overlayOpen = true);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VoiceOverlayPage(session: widget.session),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
    if (mounted) setState(() => _overlayOpen = false);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No explicit `bloc:` — the listener reads [VoiceSettingsCubit] from
    // the auth-session-shell `BlocProvider` above this widget. This
    // resolves to the same instance every page in the tree observes.
    return BlocListener<VoiceSettingsCubit, VoiceSettings>(
      listener: (context, settings) {
        if (!settings.wakeWordArmedInForeground) {
          _wakeWordService.stop();
          _stopPulse();
        } else {
          _startWakeWordIfArmed();
        }
      },
      child: _buildFab(),
    );
  }

  Widget _buildFab() {
    final bool isGuest = widget.session.isGuest;
    final bool isArmed = _wakeWordService.isRunning;
    final String tooltip = isGuest
        ? AppStrings.voiceFabTooltipGuest
        : AppStrings.voiceFabTooltipOpen;

    return Tooltip(
      message: isGuest ? tooltip : '',
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // Pulse ring — visible when wake-word engine is running
          if (isArmed)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          FloatingActionButton(
            key: VoiceOverlayKeys.fabKey,
            onPressed: isGuest ? null : _openOverlay,
            tooltip: tooltip,
            backgroundColor: isGuest
                ? AppTheme.surfaceMedium
                : AppTheme.primaryOrange,
            foregroundColor: isGuest
                ? AppTheme.textDisabled
                : AppTheme.textLight,
            elevation: 4,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isArmed ? Icons.mic : Icons.mic_none_rounded,
                key: ValueKey<bool>(isArmed),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
