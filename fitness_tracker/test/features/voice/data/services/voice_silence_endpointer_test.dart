import 'package:fitness_tracker/features/voice/data/services/voice_silence_endpointer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Table-driven coverage for [VoiceSilenceEndpointer]. Asserts the hysteresis
/// + onset-confirmation algorithm survives the four real-world traces that
/// Issue #1 and Issue #2 require it to handle. See plan-A § A1.1 and
/// KNOWN_ISSUES.md #voice-whisper-vad-thresholds-are-device-tuned.
void main() {
  // Values mirror the proposed production defaults so the tests prove the
  // shipping configuration is the one that behaves correctly.
  const onset = -40.0;
  const release = -50.0;
  const confirm = 2;
  const poll = Duration(milliseconds: 200);
  const silenceTimeout = Duration(milliseconds: 2000);
  const minVoiced = Duration(milliseconds: 300);

  VoiceSilenceEndpointer build() => VoiceSilenceEndpointer(
    onsetDbfs: onset,
    releaseDbfs: release,
    confirmSamples: confirm,
    pollInterval: poll,
    silenceTimeout: silenceTimeout,
    minVoicedDuration: minVoiced,
  );

  /// Returns the index of the first `stopForSilence` verdict, or -1 if the
  /// endpointer never asked to stop.
  int firstStopIndex(VoiceSilenceEndpointer e, List<double> samples) {
    for (var i = 0; i < samples.length; i++) {
      if (e.onSample(samples[i]) == EndpointVerdict.stopForSilence) {
        return i;
      }
    }
    return -1;
  }

  group('VoiceSilenceEndpointer', () {
    test(
      'sustained speech then 2 s silence → stopForSilence, hasSufficientVoice',
      () {
        final e = build();
        // 1 s of loud speech (5 samples @ 200 ms) → voice confirmed by sample 2.
        // Then 10 samples of pure silence (= 2 s) → must trip silence stop.
        final samples = <double>[
          -20, -20, -20, -20, -20, // 1 s voiced
          -80, -80, -80, -80, -80, -80, -80, -80, -80, -80, // 2 s silence
        ];
        final idx = firstStopIndex(e, samples);
        expect(idx, isNonNegative, reason: 'must stop within the trace');
        // 5 voiced + 10 silence — the 10th silence sample (index 14) is the
        // first that meets the 2 s budget.
        expect(idx, 14);
        expect(e.hasSufficientVoice, isTrue);
      },
    );

    test(
      'isolated spikes during silence do not reset the clock (Issue #1 fix)',
      () {
        final e = build();
        // Confirm voice (1 s), then a long silence window peppered with lone
        // loud spikes. Each spike is followed by sub-release samples so no
        // spike ever reaches confirmSamples = 2 consecutive onsets. Issue #1
        // said these spikes used to reset the legacy `_lastVoiceAt` clock and
        // the recorder ran to its 15 s hard cap. The endpointer must IGNORE
        // them: silence accrual continues until the timeout trips.
        final samples = <double>[
          -20,
          -20,
          -20,
          -20,
          -20,
          -80,
          -80,
          -80,
          -80,
          -80,
          -20,
          -80,
          -80,
          -80,
          -80,
          -80,
          -80,
          -80,
        ];
        final idx = firstStopIndex(e, samples);
        expect(idx, isNonNegative, reason: 'spikes must not reset the clock');
        expect(e.hasSufficientVoice, isTrue);
      },
    );

    test('noise-only → never stopForSilence, hasSufficientVoice false', () {
      final e = build();
      // 30 samples in the hysteresis dead-band / below release. None reach
      // confirmSamples → voice never confirmed → silence does not accrue
      // → endpointer never asks to stop via the silence path (it will
      // fall through to the hard-cap timer at 15 s in the recorder).
      final samples = List<double>.filled(30, -70);
      final idx = firstStopIndex(e, samples);
      expect(idx, -1);
      expect(e.hasSufficientVoice, isFalse);
    });

    test('brief real word (≥ minVoicedDuration) → hasSufficientVoice', () {
      final e = build();
      // 3 consecutive onset samples = 600 ms of voiced time, well over the
      // 300 ms minimum. Then enough silence to trip the timeout.
      final samples = <double>[-20, -20, -20, ...List<double>.filled(10, -80)];
      firstStopIndex(e, samples);
      expect(e.hasSufficientVoice, isTrue);
    });

    test('confirmSamples - 1 consecutive onsets → not confirmed', () {
      final e = build();
      // One onset sample only — short of confirmSamples=2. Even after
      // arbitrary silence, voice never confirmed, so hasSufficientVoice
      // stays false and the silence path cannot trip.
      final samples = <double>[-20, ...List<double>.filled(20, -80)];
      final idx = firstStopIndex(e, samples);
      expect(idx, -1);
      expect(e.hasSufficientVoice, isFalse);
    });

    test('dead-band samples accrue neither voice nor silence', () {
      final e = build();
      // Confirm voice first. confirmSamples=2, so onset starts accruing on
      // sample 2; need a third sample to reach the 300 ms minimum.
      e.onSample(-20);
      e.onSample(-20);
      e.onSample(-20);
      expect(e.hasSufficientVoice, isTrue);

      final voicedBefore = e.voicedAccumulated;
      // Dead-band: below onset (-40) but at/above release (-50). Should
      // neither add voiced time nor accumulate silence.
      for (var i = 0; i < 100; i++) {
        e.onSample(-45);
      }
      expect(e.voicedAccumulated, voicedBefore);
      // Endpointer must not have asked to stop — no silence accrued.
      expect(e.onSample(-45), EndpointVerdict.keepListening);
    });

    test('reset clears all accumulators', () {
      final e = build();
      e.onSample(-20);
      e.onSample(-20);
      e.onSample(-20);
      expect(e.hasSufficientVoice, isTrue);
      e.reset();
      expect(e.hasSufficientVoice, isFalse);
      expect(e.voicedAccumulated, Duration.zero);
    });
  });
}
