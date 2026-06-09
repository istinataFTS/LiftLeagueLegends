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

  /// FIFO queue of pending transition requests. Each entry carries its own
  /// desired running state and completer, so a superseded request still
  /// resolves once the drain reaches it — it cannot be stranded by a later
  /// opposite call coalescing the queue away.
  final List<({bool desired, Completer<void> completer})> _queue =
      <({bool desired, Completer<void> completer})>[];

  /// Non-null while [_drainQueue] is iterating. Prevents duplicate drains
  /// when [start]/[stop] are called while a drain is already in flight.
  Future<void>? _draining;

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
  Future<void> start() => _enqueue(desired: true);

  @override
  Future<void> stop() => _enqueue(desired: false);

  Future<void> _enqueue({required bool desired}) {
    final completer = Completer<void>();
    _queue.add((desired: desired, completer: completer));
    _draining ??= _drainQueue();
    return completer.future;
  }

  /// Drains [_queue] in order, issuing one native call per state change.
  /// A request whose desired state already matches [_isRunning] completes
  /// without a native call (no-op fast path); requests that flip the state
  /// invoke the method channel and complete on success / fail on error.
  Future<void> _drainQueue() async {
    try {
      while (_queue.isNotEmpty) {
        final req = _queue.removeAt(0);
        if (req.desired == _isRunning) {
          if (!req.completer.isCompleted) req.completer.complete();
          continue;
        }
        try {
          if (req.desired) {
            await _methodChannel.invokeMethod<void>('start');
            _isRunning = true;
          } else {
            await _methodChannel.invokeMethod<void>('stop');
            _isRunning = false;
          }
          if (!req.completer.isCompleted) req.completer.complete();
        } catch (error, stackTrace) {
          AppLogger.warning(
            'PlatformChannelVoiceMediaButtonService: failed to '
            '${req.desired ? "start" : "stop"}',
            error: error,
            category: _logCategory,
          );
          if (!req.completer.isCompleted) {
            req.completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _draining = null;
    }
  }

  /// Release resources. Called at app shutdown or DI teardown.
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _controller.close();
  }
}
