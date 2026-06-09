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
  Future<void> start() async {
    if (_isRunning) return;
    try {
      await _methodChannel.invokeMethod<void>('start');
      _isRunning = true;
    } catch (error) {
      AppLogger.warning(
        'PlatformChannelVoiceMediaButtonService: failed to start',
        error: error,
        category: _logCategory,
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } catch (error) {
      AppLogger.warning(
        'PlatformChannelVoiceMediaButtonService: failed to stop',
        error: error,
        category: _logCategory,
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Release resources. Called at app shutdown or DI teardown.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _controller.close();
  }
}
