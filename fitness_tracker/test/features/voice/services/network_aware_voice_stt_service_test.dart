import 'dart:async';

import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/features/voice/data/services/network_aware_voice_stt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockNetworkStatusService extends Mock implements NetworkStatusService {}

/// In-memory [VoiceSttService] double that lets tests drive the lifecycle
/// hooks directly. `emit` / `emitError` / `complete` push to whatever stream
/// the most recent [listen] call returned.
class _FakeSttService implements VoiceSttService {
  _FakeSttService({this.available = true});

  final bool available;

  bool initializeCalled = false;
  bool disposeCalled = false;
  String? lastLocaleId;
  int listenCallCount = 0;
  int stopCallCount = 0;
  int cancelCallCount = 0;

  StreamController<VoiceSttResult>? _controller;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => _controller != null && !_controller!.isClosed;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) {
    listenCallCount += 1;
    lastLocaleId = localeId;
    _controller = StreamController<VoiceSttResult>();
    return _controller!.stream;
  }

  void emit(VoiceSttResult result) => _controller?.add(result);

  void emitError(VoiceSttException err) => _controller?.addError(err);

  Future<void> complete() async {
    await _controller?.close();
    _controller = null;
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
    await complete();
  }

  @override
  Future<void> cancel() async {
    cancelCallCount += 1;
    await complete();
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
    await complete();
  }
}

void main() {
  late _FakeSttService remote;
  late _FakeSttService onDevice;
  late _MockNetworkStatusService network;
  late NetworkAwareVoiceSttService subject;

  setUp(() {
    remote = _FakeSttService();
    onDevice = _FakeSttService();
    network = _MockNetworkStatusService();
    subject = NetworkAwareVoiceSttService(
      remoteService: remote,
      onDeviceService: onDevice,
      networkStatusService: network,
    );
  });

  group('initialize', () {
    test('initializes both backends', () async {
      await subject.initialize();
      expect(remote.initializeCalled, isTrue);
      expect(onDevice.initializeCalled, isTrue);
    });

    test('partial backend init failure does not block the other', () async {
      final failing = _FakeSttService();
      final composite = NetworkAwareVoiceSttService(
        remoteService: _ThrowingSttService(),
        onDeviceService: failing,
        networkStatusService: network,
      );
      // Should not throw.
      await composite.initialize();
      expect(failing.initializeCalled, isTrue);
    });
  });

  group('routing', () {
    test('routes to remote when online', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => true);

      final results = <VoiceSttResult>[];
      final sub = subject.listen(localeId: 'en-US').listen(results.add);
      await Future<void>.delayed(Duration.zero);

      remote.emit(
        const VoiceSttResult(transcript: 'log bench press', isFinal: true),
      );
      await remote.complete();
      await sub.asFuture<void>();

      expect(remote.listenCallCount, 1);
      expect(onDevice.listenCallCount, 0);
      expect(results, hasLength(1));
      expect(results.first.transcript, 'log bench press');
    });

    test('routes to on-device when offline', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => false);

      final results = <VoiceSttResult>[];
      final sub = subject.listen().listen(results.add);
      await Future<void>.delayed(Duration.zero);

      onDevice.emit(
        const VoiceSttResult(transcript: 'log squat', isFinal: true),
      );
      await onDevice.complete();
      await sub.asFuture<void>();

      expect(onDevice.listenCallCount, 1);
      expect(remote.listenCallCount, 0);
      expect(results.single.transcript, 'log squat');
    });

    test(
      'falls back to on-device when the connectivity check throws',
      () async {
        when(network.isNetworkAvailable).thenThrow(Exception('boom'));

        final sub = subject.listen().listen((_) {});
        await Future<void>.delayed(Duration.zero);

        expect(onDevice.listenCallCount, 1);
        expect(remote.listenCallCount, 0);
        await sub.cancel();
      },
    );

    test('forwards locale to the selected backend', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => true);
      final sub = subject.listen(localeId: 'en-GB').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(remote.lastLocaleId, 'en-GB');
      await sub.cancel();
    });
  });

  group('error propagation', () {
    test('propagates errors from the active backend', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => true);

      final errors = <Object>[];
      final sub = subject.listen().listen((_) {}, onError: errors.add);
      await Future<void>.delayed(Duration.zero);

      remote.emitError(
        const VoiceSttException(VoiceSttErrorKind.network, 'offline'),
      );
      await remote.complete();
      await sub.asFuture<void>();

      expect(errors, hasLength(1));
      expect(errors.first, isA<VoiceSttException>());
    });
  });

  group('stop / cancel forwarding', () {
    test('stop() forwards to the currently active backend', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => true);

      subject.listen().listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await subject.stop();
      expect(remote.stopCallCount, 1);
      expect(onDevice.stopCallCount, 0);
    });

    test('cancel() forwards to the currently active backend', () async {
      when(network.isNetworkAvailable).thenAnswer((_) async => false);

      subject.listen().listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await subject.cancel();
      expect(onDevice.cancelCallCount, 1);
      expect(remote.cancelCallCount, 0);
    });

    test('stop() / cancel() are no-ops when no session is active', () async {
      await subject.stop();
      await subject.cancel();
      expect(remote.stopCallCount, 0);
      expect(onDevice.stopCallCount, 0);
      expect(remote.cancelCallCount, 0);
      expect(onDevice.cancelCallCount, 0);
    });
  });

  group('isAvailable', () {
    test('true when either backend reports available', () {
      expect(subject.isAvailable, isTrue);
    });

    test('false only when both backends report unavailable', () {
      final composite = NetworkAwareVoiceSttService(
        remoteService: _FakeSttService(available: false),
        onDeviceService: _FakeSttService(available: false),
        networkStatusService: network,
      );
      expect(composite.isAvailable, isFalse);
    });
  });
}

class _ThrowingSttService implements VoiceSttService {
  @override
  Future<void> initialize() async {
    throw Exception('init failed');
  }

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) =>
      throw UnimplementedError();

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
