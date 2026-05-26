import 'dart:async';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/network_status_service.dart';
import '../../../../domain/services/voice_stt_service.dart';

/// Composite [VoiceSttService] that routes each [listen] call to the best
/// available backend:
///   - When the device is online, delegates to the Whisper-backed STT
///     (server-side, better gym-jargon recognition, billed per audio
///     second).
///   - When offline (or when the online check fails), falls back to the
///     on-device Android `SpeechRecognizer` / iOS `SFSpeechRecognizer`
///     backend so voice still works without a network.
///
/// Routing decision is made once per [listen] call. Once a session has
/// started on one backend, that backend owns the lifecycle until it
/// completes — the composite does **not** swap mid-session if connectivity
/// changes.
class NetworkAwareVoiceSttService implements VoiceSttService {
  NetworkAwareVoiceSttService({
    required VoiceSttService remoteService,
    required VoiceSttService onDeviceService,
    required NetworkStatusService networkStatusService,
  }) : _remote = remoteService,
       _onDevice = onDeviceService,
       _network = networkStatusService;

  final VoiceSttService _remote;
  final VoiceSttService _onDevice;
  final NetworkStatusService _network;

  VoiceSttService? _activeBackend;

  @override
  Future<void> initialize() async {
    // Initialise both eagerly so the first `listen()` doesn't pay the
    // platform warm-up cost. Failures on one backend don't disable the
    // other — the composite tolerates partial availability.
    await Future.wait<void>([
      _safeInit(_remote, 'remote'),
      _safeInit(_onDevice, 'on-device'),
    ]);
  }

  Future<void> _safeInit(VoiceSttService service, String label) async {
    try {
      await service.initialize();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'NetworkAwareVoiceSttService: $label backend failed to initialise',
        category: 'voice',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  bool get isAvailable => _remote.isAvailable || _onDevice.isAvailable;

  @override
  bool get isListening => _activeBackend?.isListening ?? false;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) {
    if (_activeBackend != null && _activeBackend!.isListening) {
      throw StateError(
        'NetworkAwareVoiceSttService.listen() called while already listening',
      );
    }
    final controller = StreamController<VoiceSttResult>();
    unawaited(_startWithRouting(controller, localeId: localeId));
    return controller.stream;
  }

  Future<void> _startWithRouting(
    StreamController<VoiceSttResult> outbound, {
    String? localeId,
  }) async {
    final isOnline = await _resolveOnline();
    final backend = isOnline ? _remote : _onDevice;
    _activeBackend = backend;
    // Promoted from debug → info so the device-log filter
    // (`adb logcat | grep voice/stt`) shows which backend handled each
    // utterance — critical when diagnosing "mic captured nothing"
    // symptoms in the field.
    AppLogger.info(
      'NetworkAwareVoiceSttService: routing listen() to '
      '${isOnline ? 'remote (Whisper)' : 'on-device'} backend '
      '(online=$isOnline)',
      category: 'voice/stt',
    );

    StreamSubscription<VoiceSttResult>? subscription;
    subscription = backend
        .listen(localeId: localeId)
        .listen(
          (result) {
            if (!outbound.isClosed) outbound.add(result);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!outbound.isClosed) outbound.addError(error, stackTrace);
          },
          onDone: () {
            unawaited(subscription?.cancel());
            _activeBackend = null;
            if (!outbound.isClosed) outbound.close();
          },
          cancelOnError: false,
        );

    // Propagate outbound stream cancellation down to the active backend.
    outbound.onCancel = () async {
      await subscription?.cancel();
      try {
        await backend.cancel();
      } catch (_) {
        // Best-effort.
      }
      _activeBackend = null;
    };
  }

  Future<bool> _resolveOnline() async {
    try {
      return await _network.isNetworkAvailable();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'NetworkAwareVoiceSttService: connectivity check failed; '
        'falling back to on-device STT',
        category: 'voice',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> stop() async {
    final backend = _activeBackend;
    if (backend == null) return;
    await backend.stop();
  }

  @override
  Future<void> cancel() async {
    final backend = _activeBackend;
    if (backend == null) return;
    await backend.cancel();
  }

  @override
  Future<void> dispose() async {
    _activeBackend = null;
    await Future.wait<void>([
      _safeDispose(_remote, 'remote'),
      _safeDispose(_onDevice, 'on-device'),
    ]);
  }

  Future<void> _safeDispose(VoiceSttService service, String label) async {
    try {
      await service.dispose();
    } catch (error) {
      AppLogger.warning(
        'NetworkAwareVoiceSttService: $label backend dispose failed',
        category: 'voice',
        error: error,
      );
    }
  }
}
