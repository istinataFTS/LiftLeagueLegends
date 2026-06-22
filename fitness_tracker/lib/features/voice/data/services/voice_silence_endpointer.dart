/// Outcome of feeding a single amplitude sample to [VoiceSilenceEndpointer].
enum EndpointVerdict { keepListening, stopForSilence }

/// Pure, plugin-free voice-activity endpointer. Decides BOTH when to silence-
/// stop a recording and whether the captured clip contains enough sustained
/// speech to be worth uploading. Lives outside the recorder so the logic is
/// unit-testable without the `record` plugin.
///
/// Algorithm — hysteresis with onset confirmation:
///   - A sample at/above [onsetDbfs] counts toward *voice onset*.
///   - Voice is **confirmed** only after [confirmSamples] consecutive
///     onset-or-louder samples. A single stray loud sample never confirms
///     voice and never resets the silence clock.
///   - Silence accrues only while strictly below [releaseDbfs] AND voice has
///     already been confirmed once. Samples between [releaseDbfs] and
///     [onsetDbfs] sit in a hysteresis dead-band — neither voice nor silence
///     accrues — which kills the borderline-flicker reset bug.
///   - A `stopForSilence` verdict fires once
///     [_silenceAccumulated] >= [silenceTimeout] (post-confirmation).
///
/// See KNOWN_ISSUES.md #voice-whisper-vad-thresholds-are-device-tuned for the
/// rationale behind the proposed default thresholds.
class VoiceSilenceEndpointer {
  VoiceSilenceEndpointer({
    required this.onsetDbfs,
    required this.releaseDbfs,
    required this.confirmSamples,
    required this.pollInterval,
    required this.silenceTimeout,
    required this.minVoicedDuration,
  }) : assert(
         releaseDbfs < onsetDbfs,
         'releaseDbfs must be strictly less than onsetDbfs for hysteresis',
       ),
       assert(confirmSamples >= 1, 'confirmSamples must be >= 1');

  final double onsetDbfs;
  final double releaseDbfs;
  final int confirmSamples;
  final Duration pollInterval;
  final Duration silenceTimeout;
  final Duration minVoicedDuration;

  int _consecutiveVoiced = 0;
  bool _voiceConfirmed = false;
  Duration _voicedAccumulated = Duration.zero;
  Duration _silenceAccumulated = Duration.zero;

  /// Total confirmed-voiced time accumulated this session.
  Duration get voicedAccumulated => _voicedAccumulated;

  /// Whether the clip is worth uploading — true iff confirmed-voiced time
  /// reached [minVoicedDuration].
  bool get hasSufficientVoice => _voicedAccumulated >= minVoicedDuration;

  /// Feed one amplitude sample (dBFS). Returns whether the recorder should
  /// stop now for silence.
  EndpointVerdict onSample(double dbfs) {
    if (dbfs >= onsetDbfs) {
      _consecutiveVoiced++;
      if (_consecutiveVoiced >= confirmSamples) {
        _voiceConfirmed = true;
        _voicedAccumulated += pollInterval;
        _silenceAccumulated = Duration.zero;
      }
    } else {
      _consecutiveVoiced = 0;
      if (dbfs < releaseDbfs && _voiceConfirmed) {
        _silenceAccumulated += pollInterval;
      }
    }

    if (_voiceConfirmed && _silenceAccumulated >= silenceTimeout) {
      return EndpointVerdict.stopForSilence;
    }
    return EndpointVerdict.keepListening;
  }

  void reset() {
    _consecutiveVoiced = 0;
    _voiceConfirmed = false;
    _voicedAccumulated = Duration.zero;
    _silenceAccumulated = Duration.zero;
  }
}
