import '../../../../domain/services/voice_media_button_service.dart';
import 'noop_voice_media_button_service.dart';

/// Stub factory used on web and unsupported platforms.
VoiceMediaButtonService createVoiceMediaButtonService() =>
    NoopVoiceMediaButtonService();
