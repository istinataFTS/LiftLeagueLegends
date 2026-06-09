import 'dart:io';

import '../../../../domain/services/voice_media_button_service.dart';
import 'noop_voice_media_button_service.dart';
import 'platform_channel_voice_media_button_service.dart';

/// Native factory: Android gets the real MediaSession implementation;
/// all other native platforms (iOS, desktop) get the no-op.
VoiceMediaButtonService createVoiceMediaButtonService() => Platform.isAndroid
    ? PlatformChannelVoiceMediaButtonService()
    : NoopVoiceMediaButtonService();
