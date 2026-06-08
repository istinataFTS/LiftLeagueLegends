/// Abstract port for short, non-speech audio cues ("earcons") that signal
/// voice-interaction state changes.
///
/// Currently a single cue — played when the microphone opens for listening —
/// so a hands-free user (headphones, phone out of reach) knows it is their
/// turn to speak. Kept separate from [VoiceTtsService] because earcons are
/// non-verbal, low-latency, and must play even while TTS is idle.
///
/// The production implementation ([JustAudioVoiceEarconService]) plays a
/// bundled asset; tests swap a no-op fake.
abstract class VoiceEarconService {
  /// Play the "listening started" cue. Resolves when the cue has finished
  /// (or a short safety cap elapses) so the caller can open the microphone
  /// without the cue bleeding into the recording.
  ///
  /// Best-effort: must never throw — a failed cue must never block or break a
  /// voice turn.
  Future<void> playListenStart();

  /// Release native audio resources. Called at app shutdown by the DI
  /// framework; never called by [VoiceBloc].
  Future<void> dispose();
}
