import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_tracker/features/voice/data/services/platform_channel_voice_media_button_service.dart';
import 'package:fitness_tracker/features/voice/data/services/noop_voice_media_button_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sends a fake event to a registered [EventChannel] via the binary messenger.
void _sendEventChannelEvent(String channelName, Object? event) {
  const codec = StandardMethodCodec();
  final data = codec.encodeSuccessEnvelope(event);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, data, (_) {});
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannelName = 'app/voice_media_button';
  const eventChannelName = 'app/voice_media_button_events';

  group('PlatformChannelVoiceMediaButtonService', () {
    late List<String> methodCalls;
    late PlatformChannelVoiceMediaButtonService service;

    setUp(() {
      methodCalls = [];

      // Mock the method channel.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(methodChannelName), (
            MethodCall call,
          ) async {
            methodCalls.add(call.method);
            return null;
          });

      service = PlatformChannelVoiceMediaButtonService(
        methodChannel: const MethodChannel(methodChannelName),
        eventChannel: const EventChannel(eventChannelName),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(methodChannelName),
            null,
          );
      unawaited(service.dispose());
    });

    test(
      'start invokes "start" on method channel and sets isRunning',
      () async {
        expect(service.isRunning, isFalse);
        await service.start();
        expect(methodCalls, contains('start'));
        expect(service.isRunning, isTrue);
      },
    );

    test('start is idempotent — does not double-invoke', () async {
      await service.start();
      await service.start();
      expect(methodCalls.where((m) => m == 'start').length, 1);
    });

    test(
      'stop invokes "stop" on method channel and clears isRunning',
      () async {
        await service.start();
        await service.stop();
        expect(methodCalls, contains('stop'));
        expect(service.isRunning, isFalse);
      },
    );

    test('stop is a no-op when not running', () async {
      await service.stop();
      expect(methodCalls.where((m) => m == 'stop'), isEmpty);
    });

    test('stop requested during in-flight start still tears down', () async {
      final startGate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(methodChannelName), (
            MethodCall call,
          ) async {
            methodCalls.add(call.method);
            if (call.method == 'start') await startGate.future;
            return null;
          });

      final startFut = service.start();
      await Future<void>.delayed(Duration.zero);
      // start has been invoked on the channel but is still pending.
      expect(methodCalls, ['start']);
      expect(service.isRunning, isFalse);

      // stop is requested while start is mid-flight — must still tear down.
      final stopFut = service.stop();
      startGate.complete();
      await startFut;
      await stopFut;

      expect(methodCalls, ['start', 'stop']);
      expect(service.isRunning, isFalse);
    });

    test('onMediaButtonPressed emits when event channel fires', () async {
      final emitted = <void>[];
      final sub = service.onMediaButtonPressed.listen((_) => emitted.add(null));

      // Simulate the native side sending a press event.
      _sendEventChannelEvent(eventChannelName, null);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, hasLength(1));
      await sub.cancel();
    });

    test(
      'onMediaButtonPressed emits multiple times for multiple events',
      () async {
        final emitted = <void>[];
        final sub = service.onMediaButtonPressed.listen(
          (_) => emitted.add(null),
        );

        _sendEventChannelEvent(eventChannelName, null);
        _sendEventChannelEvent(eventChannelName, null);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, hasLength(2));
        await sub.cancel();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // NoopVoiceMediaButtonService
  // ---------------------------------------------------------------------------

  group('NoopVoiceMediaButtonService', () {
    late NoopVoiceMediaButtonService service;

    setUp(() {
      service = NoopVoiceMediaButtonService();
    });

    test('isRunning is always false', () {
      expect(service.isRunning, isFalse);
    });

    test('start and stop are no-ops', () async {
      await service.start();
      expect(service.isRunning, isFalse);
      await service.stop();
      expect(service.isRunning, isFalse);
    });

    test('stream never emits', () async {
      final emitted = <void>[];
      final sub = service.onMediaButtonPressed.listen((_) => emitted.add(null));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, isEmpty);
      await sub.cancel();
    });
  });
}
