import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/voice_settings.dart' show WakeWordPreset;
import '../../../../domain/services/voice_credential_service.dart';
import '../../../../domain/services/voice_wake_word_service.dart';

/// Picovoice Porcupine implementation of [VoiceWakeWordService].
///
/// Foreground-only: the engine is started on app resume (via [VoiceFab]'s
/// [WidgetsBindingObserver]) and stopped on inactive/paused. It must not
/// run while the app is backgrounded (iOS background-mic restrictions).
///
/// The Picovoice access key is always read from [VoiceCredentialService]
/// (secure storage) — never from dart-define or SharedPreferences.
class PorcupineVoiceWakeWordService implements VoiceWakeWordService {
  PorcupineVoiceWakeWordService({
    required VoiceCredentialService credentialService,
  }) : _credentials = credentialService;

  final VoiceCredentialService _credentials;

  PorcupineManager? _manager;
  bool _running = false;
  WakeWordPreset? _activePreset;

  final _detectedController = StreamController<WakeWordPreset>.broadcast();
  final _errorController = StreamController<VoiceWakeWordException>.broadcast();

  // ── VoiceWakeWordService interface ──────────────────────────────────────────

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async {
    if (_running && _activePreset == preset) return;
    await stop();

    final accessKey = await _credentials.getPicovoiceAccessKey();
    if (accessKey == null || accessKey.isEmpty) {
      throw const VoiceWakeWordException(
        VoiceWakeWordErrorKind.noAccessKey,
        'Picovoice access key not configured.',
      );
    }

    final ppnPath = await _extractAsset(_ppnAssetPath(preset));
    final pvPath = await _extractAsset('assets/wake_words/porcupine_params.pv');

    try {
      _manager = await PorcupineManager.fromKeywordPaths(
        accessKey,
        [ppnPath],
        _onWakeWordDetected,
        modelPath: pvPath,
        errorCallback: _onPorcupineError,
      );
      await _manager!.start();
      _activePreset = preset;
      _running = true;
      AppLogger.info(
        'PorcupineVoiceWakeWordService: started for preset $preset',
        category: 'voice',
      );
    } on PorcupineException catch (e, st) {
      AppLogger.warning(
        'PorcupineVoiceWakeWordService: engine error on start',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      throw VoiceWakeWordException(
        VoiceWakeWordErrorKind.engineError,
        e.message,
      );
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    try {
      await _manager?.stop();
      await _manager?.delete();
    } catch (e, st) {
      AppLogger.warning(
        'PorcupineVoiceWakeWordService: error on stop',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
    } finally {
      _manager = null;
      _running = false;
      _activePreset = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _detectedController.close();
    await _errorController.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _onWakeWordDetected(int keywordIndex) {
    if (_activePreset == null) return;
    AppLogger.debug(
      'PorcupineVoiceWakeWordService: wake word detected',
      category: 'voice',
    );
    _detectedController.add(_activePreset!);
  }

  void _onPorcupineError(PorcupineException error) {
    AppLogger.warning(
      'PorcupineVoiceWakeWordService: runtime error: ${error.message}',
      category: 'voice',
    );
    _errorController.add(
      VoiceWakeWordException(VoiceWakeWordErrorKind.engineError, error.message),
    );
  }

  /// Extracts a Flutter asset bundle file to a temporary filesystem path.
  /// Porcupine requires filesystem paths, not asset-bundle paths. Writes are
  /// idempotent — subsequent calls for the same asset overwrite the temp file.
  ///
  /// Throws [VoiceWakeWordException.modelNotFound] for zero-byte assets
  /// (i.e. placeholder files before real models are obtained).
  Future<String> _extractAsset(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      if (byteData.lengthInBytes == 0) {
        throw VoiceWakeWordException(
          VoiceWakeWordErrorKind.modelNotFound,
          'Asset $assetPath is empty — replace with a real Picovoice model.',
        );
      }
      final dir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return file.path;
    } on VoiceWakeWordException {
      rethrow;
    } catch (e, st) {
      AppLogger.warning(
        'PorcupineVoiceWakeWordService: failed to extract asset $assetPath',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      throw VoiceWakeWordException(
        VoiceWakeWordErrorKind.modelNotFound,
        'Could not extract asset $assetPath: $e',
      );
    }
  }

  /// Returns the Flutter asset path for the platform-specific `.ppn` model.
  String _ppnAssetPath(WakeWordPreset preset) {
    final platformDir = Platform.isAndroid ? 'android' : 'ios';
    final fileName = switch (preset) {
      WakeWordPreset.samoLevski => 'samo_levski_$platformDir.ppn',
      WakeWordPreset.trainer => 'trainer_$platformDir.ppn',
      WakeWordPreset.thomas => 'thomas_$platformDir.ppn',
    };
    return 'assets/wake_words/$platformDir/$fileName';
  }
}
