import 'package:fitness_tracker/core/constants/voice_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the voice timing envelope. The values here are part of
/// the product spec (CLAUDE.md §"Voice bot"). A drift between this file and
/// the production constants is a bug — bump the spec and the test together,
/// or not at all.
void main() {
  group('VoiceConstants timing envelope', () {
    test('sttListenTimeout is 15 seconds (master spec)', () {
      expect(VoiceConstants.sttListenTimeout, const Duration(seconds: 15));
    });

    test('sttSilenceTimeout is 2 seconds (matches Whisper backend)', () {
      expect(VoiceConstants.sttSilenceTimeout, const Duration(seconds: 2));
    });

    test('whisperMaxAudioDuration matches sttListenTimeout', () {
      expect(
        VoiceConstants.whisperMaxAudioDuration,
        VoiceConstants.sttListenTimeout,
      );
    });

    test(
      'whisperSilenceTimeout is 1.5s and tighter than sttSilenceTimeout',
      () {
        // The Whisper path adds an upload + transcribe round-trip after the
        // endpoint, so its silence window is intentionally shorter than the
        // on-device backend's. Device-tuned — see KNOWN_ISSUES.md
        // #voice-whisper-vad-thresholds-are-device-tuned.
        expect(
          VoiceConstants.whisperSilenceTimeout,
          const Duration(milliseconds: 1500),
        );
        expect(
          VoiceConstants.whisperSilenceTimeout <
              VoiceConstants.sttSilenceTimeout,
          isTrue,
        );
      },
    );

    test('whisper VAD dead-band is ordered: release below onset', () {
      expect(
        VoiceConstants.whisperVoiceReleaseDbfs <
            VoiceConstants.whisperVoiceOnsetDbfs,
        isTrue,
      );
    });
  });
}
