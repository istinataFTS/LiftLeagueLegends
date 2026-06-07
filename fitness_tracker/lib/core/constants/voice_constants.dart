/// Voice-bot tunables. Single source of truth for any number or duration
/// referenced by the voice feature. **Never inline these constants** ΓÇö
/// always import from here so a future tweak lives in one place.
///
/// Values mirror the master spec (see `Agreements for our implementation
/// plans.txt` ┬º3.4).
abstract final class VoiceConstants {
  VoiceConstants._();

  /// Daily voice-chat budget cap per user, in USD. Enforced server-side
  /// by the `voice-chat` Edge Function. Mirrored here only for UI
  /// presentation (budget meter, "remaining today" label).
  ///
  /// STT and TTS are device-native and cost nothing.
  static const double dailyBudgetCapUsd = 0.50;

  /// Maximum conversation turns sent to `voice-chat` per call. The
  /// server also enforces this; we cap on the client to avoid wasting
  /// bandwidth on history that will be discarded.
  static const int maxHistoryTurns = 3;

  /// Lower bound for the user-tunable TTS speech rate (1.0 = system default).
  static const double minTtsSpeechRate = 0.5;

  /// Upper bound for the user-tunable TTS speech rate.
  static const double maxTtsSpeechRate = 2.0;

  /// Default TTS speech rate (matches system default).
  static const double defaultTtsSpeechRate = 1.0;

  /// Default TTS volume (1.0 = full).
  static const double defaultTtsVolume = 1.0;

  /// STT recognition timeout — closes the session after this much silence
  /// post-speech. 2 s matches the Whisper-backend silence window and keeps
  /// the on-device path snappy after the user stops talking. Tight enough
  /// to feel responsive; loose enough that a brief mid-utterance pause
  /// doesn't truncate the user.
  static const Duration sttSilenceTimeout = Duration(seconds: 2);

  /// HTTP timeout for the `voice-chat` Edge Function call. Generous
  /// enough for GPT-4o-mini (typically 1–3 s) plus network latency,
  /// but short enough to avoid hanging indefinitely on poor connections.
  static const Duration voiceChatHttpTimeout = Duration(seconds: 30);

  /// Maximum time [VoiceBloc._dispatchMutationTool] waits for
  /// [VoiceCommandRouter] to complete a mutation's [Completer] before giving
  /// up and returning [AppStrings.voiceSpokenMutationTimedOut]. Long enough
  /// for slow SQLite writes; short enough that the user notices and retries.
  static const Duration mutationDispatchTimeout = Duration(seconds: 5);

  /// Hard upper bound for a single STT session — even if the user keeps
  /// talking, force a stop at this duration to bound audio cost and UX.
  ///
  /// 15 s accommodates multi-field edit utterances ("change carbs to 60,
  /// fat to 15") plus the Samsung warm-up restarts without ever hanging
  /// indefinitely. Matches the master spec in CLAUDE.md.
  static const Duration sttListenTimeout = Duration(seconds: 15);

  /// Maximum number of times the STT session may silently restart the
  /// recogniser after an `error_no_match` with no partial transcript yet.
  /// This covers Samsung's warm-up quirk (engine fires `no_match` before
  /// the user has spoken) without letting a stuck engine loop forever.
  static const int sttMaxNoMatchRestarts = 2;

  // ───────────────────────────────────────────────────────────────────────
  // Whisper (server-side STT)
  // ───────────────────────────────────────────────────────────────────────

  /// HTTP timeout for the `voice-transcribe` Edge Function call. Whisper
  /// processing on the server is bounded by the function-side
  /// `OPENAI_TIMEOUT_MS` (30s) — this is the client-side envelope including
  /// upload, queueing, and response. 35s leaves a small headroom over the
  /// server's 30s so the server-side `TIMEOUT` error reaches the client
  /// instead of being masked by a client-side abort.
  static const Duration voiceTranscribeHttpTimeout = Duration(seconds: 35);

  /// Hard upper bound for a Whisper-backed recording session. Audio beyond
  /// this point is dropped. Matches [sttListenTimeout] so the UX envelope
  /// is identical between the two STT backends.
  static const Duration whisperMaxAudioDuration = Duration(seconds: 15);

  /// Silence window that auto-stops the recorder. Matches [sttSilenceTimeout]
  /// so both backends end the turn at the same moment of silence — Whisper
  /// has no incremental partials, so this is the only signal the user has
  /// that recording has ended.
  static const Duration whisperSilenceTimeout = Duration(milliseconds: 2000);

  /// Amplitude (dBFS) below which the recorder is considered to be picking
  /// up silence. Values near 0 dBFS are loud; values near -160 dBFS are
  /// effectively silent. -45 dBFS is quiet-room background noise on most
  /// phone microphones — speech reliably exceeds it.
  static const double whisperSilenceAmplitudeDbfs = -45.0;

  /// Polling interval for the recorder's amplitude monitor. 200 ms gives a
  /// responsive auto-stop without burning CPU on every frame.
  static const Duration whisperAmplitudePollInterval = Duration(
    milliseconds: 200,
  );

  /// AAC bitrate for the m4a file uploaded to Whisper. 32 kbps mono is
  /// sufficient for speech and keeps the upload under 100 KB for a 20s
  /// utterance — important on mobile networks.
  static const int whisperAudioBitrate = 32000;

  /// Sample rate for the recording. 16 kHz is Whisper's optimal input — the
  /// server downsamples anything higher anyway. Mono.
  static const int whisperAudioSampleRate = 16000;

  // ───────────────────────────────────────────────────────────────────────
  // Wake word (sherpa-onnx KWS) — mic re-arm
  // ───────────────────────────────────────────────────────────────────────

  /// Max attempts to acquire the microphone when (re)arming the wake-word
  /// engine. The wake-word recorder and the Whisper STT recorder both use the
  /// `record` plugin; on Android the OS may not have released the AudioRecord
  /// from a just-finished STT turn by the time `VoiceFab` re-arms the wake word
  /// on overlay close. Retrying a few times bridges that release gap so the
  /// engine reliably comes back instead of silently staying off.
  static const int wakeWordMicAcquireMaxAttempts = 3;

  /// Backoff between microphone-acquire attempts when (re)arming the wake-word
  /// engine. Short enough to stay imperceptible; long enough for the platform
  /// to release the recorder from the prior STT session.
  static const Duration wakeWordMicAcquireRetryDelay = Duration(
    milliseconds: 250,
  );
}
