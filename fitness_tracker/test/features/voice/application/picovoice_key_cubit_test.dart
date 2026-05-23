import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/services/voice_credential_service.dart';
import 'package:fitness_tracker/features/voice/application/picovoice_key_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCredentials extends Mock implements VoiceCredentialService {}

void main() {
  late _MockCredentials credentials;

  setUp(() {
    credentials = _MockCredentials();
  });

  PicovoiceKeyCubit buildCubit() =>
      PicovoiceKeyCubit(credentials: credentials);

  group('PicovoiceKeyState', () {
    test('initial state is loading with no key and no error', () {
      const state = PicovoiceKeyState.initial();
      expect(state.hasKey, isFalse);
      expect(state.isLoading, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('copyWith clearError drops the previous error', () {
      const state = PicovoiceKeyState(
        hasKey: false,
        isLoading: false,
        isSaving: false,
        errorMessage: 'boom',
      );
      final next = state.copyWith(clearError: true);
      expect(next.errorMessage, isNull);
    });

    test('equality is value-based across all fields', () {
      const a = PicovoiceKeyState(
        hasKey: true,
        isLoading: false,
        isSaving: false,
      );
      const b = PicovoiceKeyState(
        hasKey: true,
        isLoading: false,
        isSaving: false,
      );
      expect(a, equals(b));
    });
  });

  group('PicovoiceKeyCubit.load', () {
    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'emits hasKey=true when the service reports a configured key',
      build: () {
        when(() => credentials.hasPicovoiceAccessKey())
            .thenAnswer((_) async => true);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      // load() always emits a transient isLoading=true tick (even when it
      // equals the initial state — Cubit.emit does not deduplicate) and
      // then the hydrated terminal state.
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: true,
          isSaving: false,
        ),
        const PicovoiceKeyState(
          hasKey: true,
          isLoading: false,
          isSaving: false,
        ),
      ],
      verify: (_) {
        verify(() => credentials.hasPicovoiceAccessKey()).called(1);
      },
    );

    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'emits hasKey=false when the service reports no key',
      build: () {
        when(() => credentials.hasPicovoiceAccessKey())
            .thenAnswer((_) async => false);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: true,
          isSaving: false,
        ),
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: false,
          isSaving: false,
        ),
      ],
    );

    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'emits errorMessage when the credential service throws',
      build: () {
        when(() => credentials.hasPicovoiceAccessKey())
            .thenThrow(Exception('storage offline'));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: true,
          isSaving: false,
        ),
        isA<PicovoiceKeyState>()
            .having((s) => s.isLoading, 'isLoading', isFalse)
            .having((s) => s.hasKey, 'hasKey', isFalse)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('PicovoiceKeyCubit.save', () {
    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'rejects empty strings without touching the credential service',
      build: buildCubit,
      seed: () => const PicovoiceKeyState(
        hasKey: false,
        isLoading: false,
        isSaving: false,
      ),
      act: (cubit) => cubit.save('   '),
      expect: () => <dynamic>[
        isA<PicovoiceKeyState>()
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
      verify: (_) {
        verifyNever(() => credentials.setPicovoiceAccessKey(any()));
      },
    );

    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'writes the trimmed key to storage and transitions to hasKey=true',
      build: () {
        when(() => credentials.setPicovoiceAccessKey(any()))
            .thenAnswer((_) async {});
        return buildCubit();
      },
      seed: () => const PicovoiceKeyState(
        hasKey: false,
        isLoading: false,
        isSaving: false,
      ),
      act: (cubit) => cubit.save('  raw-key  '),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: false,
          isSaving: true,
        ),
        const PicovoiceKeyState(
          hasKey: true,
          isLoading: false,
          isSaving: false,
        ),
      ],
      verify: (_) {
        // The cubit delegates trim+validation to the credential service per
        // the existing service contract; the cubit only short-circuits the
        // wholly-empty case.
        verify(() => credentials.setPicovoiceAccessKey('raw-key')).called(1);
      },
    );

    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'surfaces errorMessage when storage write throws',
      build: () {
        when(() => credentials.setPicovoiceAccessKey(any()))
            .thenThrow(Exception('storage offline'));
        return buildCubit();
      },
      seed: () => const PicovoiceKeyState(
        hasKey: false,
        isLoading: false,
        isSaving: false,
      ),
      act: (cubit) => cubit.save('some-key'),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: false,
          isSaving: true,
        ),
        isA<PicovoiceKeyState>()
            .having((s) => s.isSaving, 'isSaving', isFalse)
            .having((s) => s.hasKey, 'hasKey', isFalse)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('PicovoiceKeyCubit.clear', () {
    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'removes the key and transitions to hasKey=false',
      build: () {
        when(() => credentials.clearPicovoiceAccessKey())
            .thenAnswer((_) async {});
        return buildCubit();
      },
      seed: () => const PicovoiceKeyState(
        hasKey: true,
        isLoading: false,
        isSaving: false,
      ),
      act: (cubit) => cubit.clear(),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: true,
          isLoading: false,
          isSaving: true,
        ),
        const PicovoiceKeyState(
          hasKey: false,
          isLoading: false,
          isSaving: false,
        ),
      ],
      verify: (_) {
        verify(() => credentials.clearPicovoiceAccessKey()).called(1);
      },
    );

    blocTest<PicovoiceKeyCubit, PicovoiceKeyState>(
      'surfaces errorMessage when storage delete throws',
      build: () {
        when(() => credentials.clearPicovoiceAccessKey())
            .thenThrow(Exception('locked'));
        return buildCubit();
      },
      seed: () => const PicovoiceKeyState(
        hasKey: true,
        isLoading: false,
        isSaving: false,
      ),
      act: (cubit) => cubit.clear(),
      expect: () => <dynamic>[
        const PicovoiceKeyState(
          hasKey: true,
          isLoading: false,
          isSaving: true,
        ),
        isA<PicovoiceKeyState>()
            .having((s) => s.isSaving, 'isSaving', isFalse)
            // Key remains in storage (delete failed), so hasKey is unchanged.
            .having((s) => s.hasKey, 'hasKey', isTrue)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });
}
