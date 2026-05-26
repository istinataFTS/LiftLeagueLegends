import 'package:fitness_tracker/features/voice/data/services/secure_storage_voice_credential_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kPicovoiceKey = 'voice.picovoice_access_key';

SecureStorageVoiceCredentialService _makeService(
  FlutterSecureStorage storage,
) => SecureStorageVoiceCredentialService(storage);

void main() {
  late MockFlutterSecureStorage storage;
  late SecureStorageVoiceCredentialService service;

  setUp(() {
    storage = MockFlutterSecureStorage();
    service = _makeService(storage);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('SecureStorageVoiceCredentialService', () {
    test('getPicovoiceAccessKey reads from the correct storage key', () async {
      when(
        () => storage.read(key: _kPicovoiceKey),
      ).thenAnswer((_) async => 'my-key');

      final result = await service.getPicovoiceAccessKey();
      expect(result, 'my-key');
      verify(() => storage.read(key: _kPicovoiceKey)).called(1);
    });

    test('getPicovoiceAccessKey returns null when key absent', () async {
      when(
        () => storage.read(key: _kPicovoiceKey),
      ).thenAnswer((_) async => null);

      expect(await service.getPicovoiceAccessKey(), isNull);
    });

    test('setPicovoiceAccessKey writes trimmed key to storage', () async {
      when(
        () => storage.write(key: _kPicovoiceKey, value: 'trimmed-key'),
      ).thenAnswer((_) async {});

      await service.setPicovoiceAccessKey('  trimmed-key  ');
      verify(
        () => storage.write(key: _kPicovoiceKey, value: 'trimmed-key'),
      ).called(1);
    });

    test('setPicovoiceAccessKey throws ArgumentError on empty string', () {
      expect(
        () => service.setPicovoiceAccessKey(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'setPicovoiceAccessKey throws ArgumentError on whitespace-only string',
      () {
        expect(
          () => service.setPicovoiceAccessKey('   '),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('clearPicovoiceAccessKey deletes the correct storage key', () async {
      when(() => storage.delete(key: _kPicovoiceKey)).thenAnswer((_) async {});

      await service.clearPicovoiceAccessKey();
      verify(() => storage.delete(key: _kPicovoiceKey)).called(1);
    });

    test('hasPicovoiceAccessKey returns false when storage is empty', () async {
      when(
        () => storage.read(key: _kPicovoiceKey),
      ).thenAnswer((_) async => null);

      expect(await service.hasPicovoiceAccessKey(), isFalse);
    });

    test('hasPicovoiceAccessKey returns true after a key is set', () async {
      when(
        () => storage.read(key: _kPicovoiceKey),
      ).thenAnswer((_) async => 'some-key');

      expect(await service.hasPicovoiceAccessKey(), isTrue);
    });

    test(
      'hasPicovoiceAccessKey returns false for empty string in storage',
      () async {
        when(
          () => storage.read(key: _kPicovoiceKey),
        ).thenAnswer((_) async => '');

        expect(await service.hasPicovoiceAccessKey(), isFalse);
      },
    );

    // ── isWakeWordConfigured ─────────────────────────────────────────────────

    group('isWakeWordConfigured', () {
      test('returns false when storage is empty', () async {
        when(
          () => storage.read(key: _kPicovoiceKey),
        ).thenAnswer((_) async => null);

        expect(await service.isWakeWordConfigured(), isFalse);
      });

      test('returns false for empty string in storage', () async {
        when(
          () => storage.read(key: _kPicovoiceKey),
        ).thenAnswer((_) async => '');

        expect(await service.isWakeWordConfigured(), isFalse);
      });

      test(
        'returns false when storage holds the dart_defines placeholder',
        () async {
          when(
            () => storage.read(key: _kPicovoiceKey),
          ).thenAnswer((_) async => '<paste-your-picovoice-access-key-here>');

          expect(await service.isWakeWordConfigured(), isFalse);
        },
      );

      test('returns false for any angle-bracket-wrapped value', () async {
        when(
          () => storage.read(key: _kPicovoiceKey),
        ).thenAnswer((_) async => '<TODO>');

        expect(await service.isWakeWordConfigured(), isFalse);
      });

      test('returns true for a plausible real Picovoice key', () async {
        when(() => storage.read(key: _kPicovoiceKey)).thenAnswer(
          (_) async => 'aB3xY9pq6lk7M2nQrS5tV1wZ8oP4iU6yE0wRtY8uIoP=',
        );

        expect(await service.isWakeWordConfigured(), isTrue);
      });

      test(
        'returns true even for short keys that are not placeholders',
        () async {
          when(
            () => storage.read(key: _kPicovoiceKey),
          ).thenAnswer((_) async => 'abc');

          expect(await service.isWakeWordConfigured(), isTrue);
        },
      );
    });

    // ── onPicovoiceKeyChanged stream ─────────────────────────────────────────

    group('onPicovoiceKeyChanged', () {
      test('emits an event when the key is set', () async {
        when(
          () => storage.write(key: _kPicovoiceKey, value: 'new-key'),
        ).thenAnswer((_) async {});

        expectLater(service.onPicovoiceKeyChanged, emits(anything));

        await service.setPicovoiceAccessKey('new-key');
      });

      test('emits an event when the key is cleared', () async {
        when(
          () => storage.delete(key: _kPicovoiceKey),
        ).thenAnswer((_) async {});

        expectLater(service.onPicovoiceKeyChanged, emits(anything));

        await service.clearPicovoiceAccessKey();
      });

      test('emits one event per set call', () async {
        when(
          () => storage.write(
            key: _kPicovoiceKey,
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        final events = <void>[];
        final sub = service.onPicovoiceKeyChanged.listen(
          (_) => events.add(null),
        );

        await service.setPicovoiceAccessKey('key-1');
        await service.setPicovoiceAccessKey('key-2');
        await service.setPicovoiceAccessKey('key-3');

        await sub.cancel();
        expect(events, hasLength(3));
      });

      test('emits one event per clear call', () async {
        when(
          () => storage.delete(key: _kPicovoiceKey),
        ).thenAnswer((_) async {});

        final events = <void>[];
        final sub = service.onPicovoiceKeyChanged.listen(
          (_) => events.add(null),
        );

        await service.clearPicovoiceAccessKey();
        await service.clearPicovoiceAccessKey();

        await sub.cancel();
        expect(events, hasLength(2));
      });

      test(
        'getPicovoiceAccessKey does NOT emit an event (read-only)',
        () async {
          when(
            () => storage.read(key: _kPicovoiceKey),
          ).thenAnswer((_) async => 'some-key');

          var emitCount = 0;
          final sub = service.onPicovoiceKeyChanged.listen((_) => emitCount++);

          await service.getPicovoiceAccessKey();
          await service.hasPicovoiceAccessKey();

          await sub.cancel();
          expect(emitCount, 0);
        },
      );

      test('stream delivers to multiple concurrent listeners', () async {
        when(
          () => storage.write(key: _kPicovoiceKey, value: 'k'),
        ).thenAnswer((_) async {});

        var count1 = 0;
        var count2 = 0;
        final sub1 = service.onPicovoiceKeyChanged.listen((_) => count1++);
        final sub2 = service.onPicovoiceKeyChanged.listen((_) => count2++);

        await service.setPicovoiceAccessKey('k');

        await sub1.cancel();
        await sub2.cancel();
        expect(count1, 1);
        expect(count2, 1);
      });
    });
  });
}
