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
    return _transition = _reconcile(_transition);
  }

  @override
  Future<void> stop() {
    _desiredRunning = false;
    return _transition = _reconcile(_transition);
  }

  /// Drives the native session toward [_desiredRunning] after [previous]
  /// completes. The loop re-checks the desired state after every
  /// method-channel call so a flip-flop during an in-flight call is
  /// honoured once the call resolves.
  Future<void> _reconcile(Future<void> previous) async {
    await previous;
    while (_desiredRunning != _isRunning) {
      final desired = _desiredRunning;
      try {
        if (desired) {
          await _methodChannel.invokeMethod<void>('start');
          _isRunning = true;
        } else {
          await _methodChannel.invokeMethod<void>('stop');
          _isRunning = false;
        }
      } catch (error) {
        AppLogger.warning(
          'PlatformChannelVoiceMediaButtonService: failed to '
          '${desired ? "start" : "stop"}',
          error: error,
          category: _logCategory,
        );
        return;
      }
    }
  }

  /// Release resources. Called at app shutdown or DI teardown.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _controller.close();
  }
}
