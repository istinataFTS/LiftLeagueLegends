import 'dart:async';

import '../../../../domain/services/voice_media_button_service.dart';

/// No-op [VoiceMediaButtonService] used on non-Android platforms.
///
/// The stream never emits; [isRunning] is always false. Keeps the domain layer
/// platform-agnostic — iOS/web code can depend on the port without a real
/// native session.
class NoopVoiceMediaButtonService implements VoiceMediaButtonService {
  NoopVoiceMediaButtonService()
    : _controller = StreamController<void>.broadcast();

  final StreamController<void> _controller;

  @override
  Stream<void> get onMediaButtonPressed => _controller.stream;

  @override
  bool get isRunning => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
