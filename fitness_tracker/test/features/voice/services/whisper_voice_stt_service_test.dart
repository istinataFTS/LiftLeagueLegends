import 'dart:io';
import 'dart:typed_data';

import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/services/voice_pre_roll_store.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/features/voice/data/services/wav_utils.dart';
import 'package:fitness_tracker/features/voice/data/services/whisper_voice_stt_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the static [WhisperVoiceSttService.classifyTranscribeError] helper.
/// The lifecycle/recording behavior of the service is dominated by platform
/// I/O (the `record` plugin's `AudioRecorder`) and is exercised end-to-end via
/// the voice-bloc integration tests; here we lock down the failure-to-kind
/// mapping that drives every user-facing error message.
void main() {
  group('classifyTranscribeError', () {
    // ── Structured edge-function codes ──────────────────────────────────────

    test('UNAUTHORIZED → auth', () {
      const err = ServerFailure('UNAUTHORIZED|401|Missing or invalid token');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.auth,
      );
    });

    test('GUEST_FORBIDDEN → auth', () {
      const err = ServerFailure('GUEST_FORBIDDEN|403|Sign in to use voice');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.auth,
      );
    });

    test('BUDGET_EXCEEDED → budgetExceeded', () {
      const err = ServerFailure('BUDGET_EXCEEDED|429|Daily budget exhausted');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.budgetExceeded,
      );
    });

    test('INVALID_REQUEST + 413 → audioTooLarge', () {
      const err = ServerFailure('INVALID_REQUEST|413|Audio file too large');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.audioTooLarge,
      );
    });

    test('INVALID_REQUEST without 413 → unknown', () {
      const err = ServerFailure('INVALID_REQUEST|400|Missing field');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.unknown,
      );
    });

    test('OPENAI_UNAVAILABLE → serverUnavailable', () {
      const err = ServerFailure('OPENAI_UNAVAILABLE|502|Upstream is down');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.serverUnavailable,
      );
    });

    test('RATE_LIMITED → serverUnavailable', () {
      const err = ServerFailure('RATE_LIMITED|429|Slow down');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.serverUnavailable,
      );
    });

    test('INTERNAL → serverUnavailable', () {
      const err = ServerFailure('INTERNAL|500|Crashed');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.serverUnavailable,
      );
    });

    test('TIMEOUT code prefix → network', () {
      const err = ServerFailure('TIMEOUT|0|Did not respond in time');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.network,
      );
    });

    // ── Legacy / unencoded ServerFailure ────────────────────────────────────

    test('legacy "TIMEOUT: …" message → network', () {
      const err = ServerFailure('TIMEOUT: server did not respond in time');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.network,
      );
    });

    test('legacy network keyword → network', () {
      const err = ServerFailure('Network unreachable');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.network,
      );
    });

    // ── Transport-level exceptions ──────────────────────────────────────────

    test('SocketException → network', () {
      const err = SocketException('Connection reset by peer');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.network,
      );
    });

    test('HttpException → network', () {
      const err = HttpException('Server hung up');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.network,
      );
    });

    // ── Anything else ───────────────────────────────────────────────────────

    test('arbitrary throwable → unknown', () {
      final err = Exception('mystery');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.unknown,
      );
    });

    test('ServerFailure without code prefix → unknown', () {
      const err = ServerFailure('whoops');
      expect(
        WhisperVoiceSttService.classifyTranscribeError(err),
        VoiceSttErrorKind.unknown,
      );
    });
  });

  group('shouldTranscribe', () {
    test(
      'insufficient voice, non-empty bytes → false (silence clip, the FEMA case)',
      () {
        expect(
          WhisperVoiceSttService.shouldTranscribe(
            hasSufficientVoice: false,
            byteCount: 7100,
          ),
          isFalse,
        );
      },
    );

    test('insufficient voice, zero bytes → false', () {
      expect(
        WhisperVoiceSttService.shouldTranscribe(
          hasSufficientVoice: false,
          byteCount: 0,
        ),
        isFalse,
      );
    });

    test('sufficient voice, zero bytes → false (defensive)', () {
      expect(
        WhisperVoiceSttService.shouldTranscribe(
          hasSufficientVoice: true,
          byteCount: 0,
        ),
        isFalse,
      );
    });

    test('sufficient voice, non-empty bytes → true', () {
      expect(
        WhisperVoiceSttService.shouldTranscribe(
          hasSufficientVoice: true,
          byteCount: 5000,
        ),
        isTrue,
      );
    });
  });

  group('applyPreRoll', () {
    const sampleRate = 16000;

    Uint8List pcm(int n) =>
        Uint8List.fromList(List<int>.generate(n, (i) => i % 256));

    PreRollClip clip(Uint8List body) => PreRollClip(
      pcm16: body,
      sampleRate: sampleRate,
      capturedAt: DateTime(2026),
    );

    test('null pre-roll → live bytes pass through untouched', () {
      final live = buildWav(pcm(40), sampleRate: sampleRate);
      final out = WhisperVoiceSttService.applyPreRoll(
        liveBytes: live,
        preRoll: null,
        sampleRate: sampleRate,
      );
      expect(out.hadPreRoll, isFalse);
      expect(identical(out.bytes, live), isTrue);
    });

    test('empty pre-roll → live bytes pass through untouched', () {
      final live = buildWav(pcm(40), sampleRate: sampleRate);
      final out = WhisperVoiceSttService.applyPreRoll(
        liveBytes: live,
        preRoll: clip(Uint8List(0)),
        sampleRate: sampleRate,
      );
      expect(out.hadPreRoll, isFalse);
      expect(identical(out.bytes, live), isTrue);
    });

    test(
      'fresh pre-roll → spliced WAV with pre-roll ahead of the live body',
      () {
        final preBody = pcm(30);
        final liveBody = pcm(40);
        final live = buildWav(liveBody, sampleRate: sampleRate);

        final out = WhisperVoiceSttService.applyPreRoll(
          liveBytes: live,
          preRoll: clip(preBody),
          sampleRate: sampleRate,
        );

        expect(out.hadPreRoll, isTrue);
        final body = wavPcmBody(out.bytes);
        expect(body.length, preBody.length + liveBody.length);
        expect(body.sublist(0, preBody.length), preBody);
        expect(body.sublist(preBody.length), liveBody);
      },
    );
  });
}
