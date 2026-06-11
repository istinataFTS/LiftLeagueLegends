import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/app_session.dart';
import '../../../../domain/entities/voice_settings.dart';
import '../../../../domain/services/voice_media_button_service.dart';
import '../../../../domain/services/voice_permission_service.dart';
import '../../../../domain/services/voice_wake_word_service.dart';
import '../../../../injection/injection_container.dart';
import '../../application/voice_settings_cubit.dart';
import '../voice_overlay_keys.dart';
import '../voice_overlay_page.dart';

/// Persistent floating action button that opens the voice overlay and
/// manages the wake-word engine lifecycle.
///
/// Implements [WidgetsBindingObserver] so the wake-word engine is automatically
/// stopped when the app goes to the background (foreground-only mic policy)
/// and restarted on resume.
///
/// Only reachable above the auth gate — every visible instance has an
/// authenticated session.
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

  /// Media-button service is a DI singleton, captured once in [initState].
  /// Lifecycle mirrors [_wakeWordService] — started/stopped at the same gates.
  late final VoiceMediaButtonService _mediaButtonService;

  StreamSubscription<WakeWordPreset>? _wakeWordSub;
  StreamSubscription<VoiceWakeWordException>? _wakeWordErrorSub;
  StreamSubscription<void>? _mediaButtonSub;
  bool _overlayOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakeWordService = sl<VoiceWakeWordService>();
    _mediaButtonService = sl<VoiceMediaButtonService>();

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
    _listenToMediaButtonStream();
    unawaited(_startWakeWordIfArmed());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakeWordSub?.cancel();
    _wakeWordErrorSub?.cancel();
    _mediaButtonSub?.cancel();
    unawaited(_wakeWordService.stop());
    unawaited(_mediaButtonService.stop());
    _pulseController.dispose();
    super.dispose();
  }

  // ── App lifecycle ───────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startWakeWordIfArmed());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_wakeWordService.stop());
        unawaited(_mediaButtonService.stop());
        _stopPulse();
    }
  }

  // ── Wake-word management ────────────────────────────────────────────────────

  Future<void> _startWakeWordIfArmed() async {
    if (!mounted) return;
    final cubit = context.read<VoiceSettingsCubit>();
    await cubit.ready;
    if (!mounted) return;
    final settings = cubit.state;
    if (!settings.wakeWordArmedInForeground) return;
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
    _mediaButtonService.start().catchError((Object e) {
      AppLogger.warning(
        'VoiceFab: failed to start media-button service',
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

  void _listenToMediaButtonStream() {
    _mediaButtonSub = _mediaButtonService.onMediaButtonPressed.listen((_) {
      _onWakeWordFired();
    });
  }

  void _onWakeWordFired() {
    if (!mounted) return;
    if (_overlayOpen) return; // Overlay handles the listen trigger itself
    _openOverlay(openedByWakeWord: true);
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

  Future<void> _openOverlay({bool openedByWakeWord = false}) async {
    if (_overlayOpen || !mounted) return;

    final permissionService = sl<VoicePermissionService>();
    var status = await permissionService.checkMicrophonePermission();
    if (status == VoicePermissionStatus.denied) {
      status = await permissionService.requestMicrophonePermission();
    }
    if (!mounted) return;
    if (status != VoicePermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.voiceFabMicPermissionDenied),
          action: SnackBarAction(
            label: AppStrings.voiceFabMicPermissionOpenSettings,
            onPressed: permissionService.openAppSettings,
          ),
        ),
      );
      return;
    }

    setState(() => _overlayOpen = true);

    // Release the mic from the wake-word engine before the overlay's STT
    // tries to acquire it. The wake-word engine holds the mic continuously while armed;
    // on Android the recorder will silently fail to capture any audio if
    // another listener already owns the input stream. Stopping here, and
    // restarting after the overlay closes, keeps the two paths from racing.
    final bool wakeWordWasRunning = _wakeWordService.isRunning;
    if (wakeWordWasRunning) {
      try {
        await _wakeWordService.stop();
      } catch (error, stackTrace) {
        AppLogger.warning(
          'VoiceFab: failed to stop wake word before overlay push',
          error: error,
          stackTrace: stackTrace,
          category: 'voice',
        );
      }
      _stopPulse();
    }
    // Stop the media-button service unconditionally — it can be active even
    // when the wake-word engine isn't (e.g. wake-word start failed but
    // media-button start succeeded). Without this, the media session would
    // leak across the overlay handoff.
    unawaited(_mediaButtonService.stop());

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VoiceOverlayPage(
              session: widget.session,
              openedByWakeWord: openedByWakeWord,
            ),
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
    if (mounted) {
      setState(() => _overlayOpen = false);
      // Re-arm the wake-word engine if it was running before we opened the
      // overlay AND the setting is still on. `_startWakeWordIfArmed` re-reads
      // the cubit so toggling the setting while the overlay was open is
      // respected.
      if (wakeWordWasRunning) {
        unawaited(_startWakeWordIfArmed());
      }
    }
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
          _mediaButtonService.stop();
          _stopPulse();
        } else {
          unawaited(_startWakeWordIfArmed());
        }
      },
      child: _buildFab(),
    );
  }

  Widget _buildFab() {
    final bool isArmed = _wakeWordService.isRunning;

    return Stack(
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
          onPressed: _openOverlay,
          tooltip: AppStrings.voiceFabTooltipOpen,
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: AppTheme.textLight,
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
    );
  }
}
