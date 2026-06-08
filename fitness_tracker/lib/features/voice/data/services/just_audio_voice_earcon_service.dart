import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/services/voice_earcon_service.dart';

/// `just_audio` implementation of [VoiceEarconService].
///
/// Loads the bundled earcon asset once, then replays it (seek-to-zero + play)
/// on each cue. All playback is best-effort and bounded by
/// [VoiceConstants.earconMaxDuration] so a stuck player can never hang a voice
/// turn. Routed through the normal media output, so it is audible on
/// connected Bluetooth headphones.
class JustAudioVoiceEarconService implements VoiceEarconService {
  /// [player] is injectable for tests; omit in production.
  JustAudioVoiceEarconService([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _assetLoaded = false;

  static const String _assetPath = 'assets/audio/listen_start.wav';
  static const String _logCategory = 'voice/earcon';

  @override
  Future<void> playListenStart() async {
    try {
      if (!_assetLoaded) {
        await _player.setAsset(_assetPath);
        _assetLoaded = true;
      }
      await _player.seek(Duration.zero);
      // play() completes when the clip finishes; the timeout guarantees we
      // never block a voice turn if playback stalls.
      await _player.play().timeout(
        VoiceConstants.earconMaxDuration,
        onTimeout: () {},
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JustAudioVoiceEarconService: failed to play listen-start earcon',
        error: error,
        stackTrace: stackTrace,
        category: _logCategory,
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {
      // Best-effort — player may already be torn down.
    }
  }
}
