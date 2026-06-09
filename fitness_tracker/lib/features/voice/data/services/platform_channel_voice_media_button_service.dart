import 'dart:async';

import 'package:flutter/services.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/services/voice_media_button_service.dart';

/// Android implementation of [VoiceMediaButtonService].
///
/// Talks to the native [MediaSessionCompat] in [MainActivity] over a
/// [MethodChannel] (start/stop) and an [EventChannel] (press events).
/// Degrades gracefully if the native side is unavailable — errors are logged
/// and the stream is simply never populated.
class PlatformChannelVoiceMediaButtonService
    implements VoiceMediaButtonService {
  static const _methodChannelName = 'app/voice_media_button';
  static const _eventChannelName = 'app/voice_media_button_events';
  static const _logCategory = 'voice/media_button';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final StreamController<void> _controller = StreamController<void>.broadcast();

  StreamSubscription<Object?>? _eventSub;
  bool _isRunning = false;

  /// Latest desired running state. Toggled synchronously by [start]/[stop]
  /// so a `stop` requested mid-`start` is observed once the in-flight
  /// method-channel call completes.
  bool _desiredRunning = false;

  /// Chain of pending transitions. Serializes start/stop so they cannot
  /// race on the native session.
  Future<void> _transition = Future<void>.value();

  /// Completers waiting for the next successful native `start` to land.
  /// Each [start] call enqueues its own completer so callers observe their
  /// own requested transition rather than the latest coalesced state.
  final List<Completer<void>> _pendingStart = <Completer<void>>[];

  /// Completers waiting for the next successful native `stop` to land
  /// (or for the session to already be inactive when [stop] was called).
  final List<Completer<void>> _pendingStop = <Completer<void>>[];

  PlatformChannelVoiceMediaButtonService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(_methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(_eventChannelName) {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (_) => _controller.add(null),
      onError: (Object error) {
        AppLogger.warning(
          'PlatformChannelVoiceMediaButtonService: event channel error',
          error: error,
          category: _logCategory,
        );
      },
    );
  }

  @override
  Stream<void> get onMediaButtonPressed => _controller.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start() {
    _desiredRunning = true;
    final completer = Completer<void>();
    _pendingStart.add(completer);
    _transition = _reconcile(_transition);
    return completer.future;
  }

  @override
  Future<void> stop() {
    _desiredRunning = false;
    final completer = Completer<void>();
    _pendingStop.add(completer);
    _transition = _reconcile(_transition);
    return completer.future;
  }

  /// Drives the native session toward [_desiredRunning] after [previous]
  /// completes. After each native call, only the completers queued for
  /// that specific transition resolve — so an `await start()` followed by
  /// a `stop()` sees `isRunning == true` on its own completion, not the
  /// later coalesced state.
  Future<void> _reconcile(Future<void> previous) async {
    await previous;
    while (true) {
      // Already at the desired state — drain any matching no-op waiters
      // (e.g. start() when already running, stop() when already stopped).
      if (_desiredRunning == _isRunning) {
        _drain(_desiredRunning ? _pendingStart : _pendingStop);
        return;
      }
      final desired = _desiredRunning;
      try {
        if (desired) {
          await _methodChannel.invokeMethod<void>('start');
          _isRunning = true;
          _drain(_pendingStart);
        } else {
          await _methodChannel.invokeMethod<void>('stop');
          _isRunning = false;
          _drain(_pendingStop);
        }
      } catch (error, stackTrace) {
        AppLogger.warning(
          'PlatformChannelVoiceMediaButtonService: failed to '
          '${desired ? "start" : "stop"}',
          error: error,
          category: _logCategory,
        );
        _drainWithError(
          desired ? _pendingStart : _pendingStop,
          error,
          stackTrace,
        );
        return;
      }
    }
  }

  void _drain(List<Completer<void>> queue) {
    final pending = List<Completer<void>>.of(queue);
    queue.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.complete();
    }
  }

  void _drainWithError(
    List<Completer<void>> queue,
    Object error,
    StackTrace stackTrace,
  ) {
    final pending = List<Completer<void>>.of(queue);
    queue.clear();
    for (final c in pending) {
      if (!c.isCompleted) c.completeError(error, stackTrace);
    }
  }

  /// Release resources. Called at app shutdown or DI teardown.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _controller.close();
  }
}
