import 'dart:io';

import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
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
}
