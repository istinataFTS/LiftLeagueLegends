import 'dart:typed_data';

import 'package:fitness_tracker/domain/services/voice_pre_roll_store.dart';
import 'package:fitness_tracker/features/voice/data/services/in_memory_voice_pre_roll_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../integration/support/fake_clock.dart';

void main() {
  late FakeClock clock;
  late InMemoryVoicePreRollStore store;

  final t0 = DateTime(2026, 6, 13, 12);

  setUp(() {
    clock = FakeClock(t0);
    store = InMemoryVoicePreRollStore(clock: clock);
  });

  PreRollClip clipOf(int bytes, {DateTime? at}) => PreRollClip(
    pcm16: Uint8List(bytes),
    sampleRate: 16000,
    capturedAt: at ?? clock.now(),
  );

  group('take', () {
    test('returns the clip when within maxAge', () {
      store.put(clipOf(10));
      clock.advance(const Duration(milliseconds: 500));
      final clip = store.take(maxAge: const Duration(seconds: 1));
      expect(clip, isNotNull);
      expect(clip!.pcm16.length, 10);
    });

    test('is single-shot — a second take returns null', () {
      store.put(clipOf(10));
      expect(store.take(maxAge: const Duration(seconds: 1)), isNotNull);
      expect(store.take(maxAge: const Duration(seconds: 1)), isNull);
    });

    test('returns null when the clip is older than maxAge', () {
      store.put(clipOf(10));
      clock.advance(const Duration(seconds: 2));
      expect(store.take(maxAge: const Duration(seconds: 1)), isNull);
    });

    test('returns null when no clip was ever stored', () {
      expect(store.take(maxAge: const Duration(seconds: 1)), isNull);
    });

    test('treats an empty clip as nothing to consume', () {
      store.put(clipOf(0));
      expect(store.take(maxAge: const Duration(seconds: 1)), isNull);
    });
  });

  group('put', () {
    test('replaces an existing clip', () {
      store.put(clipOf(10));
      store.put(clipOf(20));
      final clip = store.take(maxAge: const Duration(seconds: 1));
      expect(clip!.pcm16.length, 20);
    });
  });

  group('clear', () {
    test('drops a stored clip without consuming it', () {
      store.put(clipOf(10));
      store.clear();
      expect(store.take(maxAge: const Duration(seconds: 1)), isNull);
    });
  });
}
