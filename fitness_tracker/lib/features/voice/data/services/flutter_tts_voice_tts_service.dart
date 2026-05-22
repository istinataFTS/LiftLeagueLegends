import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/services/voice_tts_service.dart';

/// Device-native TTS via the `flutter_tts` plugin.
///
/// Wraps [FlutterTts]'s fire-and-forget [speak] call into a Future that
/// completes when the TTS engine finishes speaking (or when [stop] is
/// called). This allows [VoiceBloc._speak] to `await` completion before
/// transitioning back to [VoiceStatus.idle].
///
/// Android uses [TextToSpeech]; iOS uses [AVSpeechSynthesizer]. Both are
/// fully on-device — no audio leaves the phone and no API key is required.
class FlutterTtsVoiceTtsService implements VoiceTtsService {
  /// [tts] can be injected in tests; omit in production to use the real engine.
  FlutterTtsVoiceTtsService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;
  Completer<void>? _speechCompleter;

  // ── VoiceTtsService interface ───────────────────────────────────────────────

  @override
  Future<void> initialize({
    double volume = VoiceConstants.defaultTtsVolume,
    double speechRate = VoiceConstants.defaultTtsSpeechRate,
  }) async {
    if (_initialized) return;

    _tts.setCompletionHandler(_onCompletion);
    _tts.setErrorHandler(_onError);

    await _tts.setLanguage('en-US');
    await _tts.setVolume(volume);
    await _tts.setSpeechRate(speechRate);

    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _ensureInitialized();

    // Interrupt any in-flight speech so back-to-back speak() calls don't queue.
    await _tts.stop();
    _completePendingSpeech();

    final completer = Completer<void>();
    _speechCompleter = completer;
    await _tts.speak(text);
    return completer.future;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _completePendingSpeech();
  }

  @override
  Future<void> setVolume(double volume) async {
    await _ensureInitialized();
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _ensureInitialized();
    await _tts.setSpeechRate(
      rate.clamp(
        VoiceConstants.minTtsSpeechRate,
        VoiceConstants.maxTtsSpeechRate,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    _initialized = false;
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _ensureInitialized() async {
    if (!_initialized) await initialize();
  }

  void _onCompletion() => _completePendingSpeech();

  void _onError(dynamic message) {
    AppLogger.warning('FlutterTtsVoiceTtsService error: $message');
    _completePendingSpeech();
  }

  void _completePendingSpeech() {
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    _speechCompleter = null;
  }
}
