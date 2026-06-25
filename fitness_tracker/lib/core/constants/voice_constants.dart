/// Voice-bot tunables. Single source of truth for any number or duration
/// referenced by the voice feature. **Never inline these constants** ΓÇö
/// always import from here so a future tweak lives in one place.
///
/// Values mirror the master spec (see `Agreements for our implementation
/// plans.txt` ┬º3.4).
abstract final class VoiceConstants {
  VoiceConstants._();

  /// Default daily voice-chat budget cap shown in the UI (budget meter,
  /// "remaining today" label). The server reads the authoritative cap from
  /// the `DAILY_BUDGET_CAP_USD` Edge Function secret and enforces it
  /// regardless of this value. To raise or lower the cap, set the secret in
  /// the Supabase dashboard (Project → Edge Functions → Manage secrets) — no
  /// code change or redeployment needed. Update this constant only to keep
  /// the UI display in sync with the server value.
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

  /// Upper bound on how long a manual Stop waits for the backend's post-stop
  /// final/error before giving up, speaking the no-speech line, and returning
  /// to idle. Derived from [voiceTranscribeHttpTimeout] plus a small margin so
  /// a slow upload still resolves through the normal pipeline before the
  /// watchdog fires. Stop can therefore never hang the transcribing spinner.
  static const Duration manualStopFinalizeTimeout = Duration(
    seconds: 35 + 3,
  ); // voiceTranscribeHttpTimeout + 3s margin

  /// Hard upper bound for a Whisper-backed recording session. Audio beyond
  /// this point is dropped. Matches [sttListenTimeout] so the UX envelope
  /// is identical between the two STT backends.
  static const Duration whisperMaxAudioDuration = Duration(seconds: 15);

  /// Silence window that auto-stops the recorder. Much shorter than
  /// [sttSilenceTimeout] (the on-device backend's window) because the Whisper
  /// path adds an upload + transcribe round-trip on top, so the *perceived*
  /// endpoint latency is this window plus the server round-trip — only this
  /// window is client-tunable. Lowered 2000 → 1500 → 1000 ms across device
  /// tests; 1 s (5 amplitude polls) still clears a normal inter-word pause
  /// (typically < 700 ms) without truncating. If a thoughtful mid-utterance
  /// pause starts getting cut, bump back toward 1200 ms. PROPOSED —
  /// device-tuned; see KNOWN_ISSUES.md
  /// #voice-whisper-vad-thresholds-are-device-tuned.
  static const Duration whisperSilenceTimeout = Duration(milliseconds: 1000);

  /// Amplitude (dBFS) at/above which a sample counts toward confirming the
  /// user is speaking. Higher (less negative) than a single-threshold value so
  /// quiet-room background noise no longer registers as voice. PROPOSED — must
  /// be validated against real device captures (see KNOWN_ISSUES.md
  /// #voice-whisper-vad-thresholds-are-device-tuned).
  static const double whisperVoiceOnsetDbfs = -40.0;

  /// Amplitude (dBFS) strictly below which silence accrues. Lower than
  /// [whisperVoiceOnsetDbfs] to form a hysteresis dead-band that ignores
  /// borderline flicker. Raised from -50 to -45 after on-device captures:
  /// a quiet room floors around -46 to -50 dBFS, which at -50 sat inside the
  /// dead-band so silence never accrued and the recorder ran to the hard cap.
  /// At -45 the ambient floor counts as silence and the recorder endpoints
  /// promptly. PROPOSED — device-tuned, validate per device.
  static const double whisperVoiceReleaseDbfs = -45.0;

  /// Consecutive onset-or-louder samples required before voice is "confirmed".
  /// Debounces isolated spikes (a single clank must not confirm voice or
  /// reset the silence clock). At a 200 ms poll, 2 samples = 400 ms.
  static const int whisperVoiceConfirmSamples = 2;

  /// Minimum total confirmed-voiced duration a clip must contain before it is
  /// uploaded for transcription. Below this the clip is treated as noise-only
  /// and dropped (emits noSpeech) so Whisper is never asked to transcribe
  /// silence. PROPOSED — validate against the shortest real one-word command
  /// ("done", "stop") so legitimate short utterances are NOT dropped.
  static const Duration whisperMinVoicedDuration = Duration(milliseconds: 300);

  /// Polling interval for the recorder's amplitude monitor. 200 ms gives a
  /// responsive auto-stop without burning CPU on every frame.
  static const Duration whisperAmplitudePollInterval = Duration(
    milliseconds: 200,
  );

  /// AAC bitrate, in bps. No longer used by the Whisper upload path — the
  /// recorder now emits WAV/PCM16 so the live clip and the wake-word pre-roll
  /// share one lossless format and splice without a re-encode. Kept for
  /// reference (and in case an AAC fallback is ever reinstated).
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

  // ───────────────────────────────────────────────────────────────────────
  // Earcon (non-speech audio cues)
  // ───────────────────────────────────────────────────────────────────────

  /// Upper bound on how long the "listening started" earcon may block before
  /// the microphone opens anyway. Keeps the pre-listen delay imperceptible
  /// while guaranteeing a stuck audio player never hangs a voice turn.
  static const Duration earconMaxDuration = Duration(milliseconds: 600);

  // ───────────────────────────────────────────────────────────────────────
  // Wake word (sherpa-onnx KWS) — recognition sensitivity
  // ───────────────────────────────────────────────────────────────────────

  /// sherpa-onnx KWS detection threshold. A keyword fires when its score
  /// exceeds this value. LOWER = more sensitive (more detections, more false
  /// positives). Lowered from the sherpa default 0.25 to 0.20 to cut misses
  /// on short wake phrases ("Thomas", "Trainer"). Device-tuned — see
  /// KNOWN_ISSUES.md #voice-wake-word-keyword-miss-rate.
  static const double wakeWordKeywordsThreshold = 0.20;

  /// sherpa-onnx KWS boosting score added to keyword tokens during decoding.
  /// HIGHER = more likely to trigger. Raised from 1.0 to 1.5 to strengthen
  /// short-keyword detection without flooding false positives.
  static const double wakeWordKeywordsScore = 1.5;

  // ───────────────────────────────────────────────────────────────────────
  // Wake word (sherpa-onnx KWS) — pre-roll capture
  // ───────────────────────────────────────────────────────────────────────

  /// Rolling window of recent mic audio the wake-word engine retains so the
  /// words spoken right after the wake word survive the wake→STT mic handoff.
  /// 3 s comfortably covers a one-breath command ("Thomas, log me bench
  /// press"). At 16 kHz mono PCM16 this is ~96 KB of buffer — negligible.
  static const Duration wakeWordPreRollDuration = Duration(seconds: 3);

  /// A detection must have fired within this window of the wake engine's
  /// `stop()` for the ring buffer to be published as pre-roll. Bounds the
  /// buffer to real wake-initiated handoffs (not app-background / settings-off
  /// stops, which also call `stop()`).
  static const Duration wakeWordPreRollDetectionWindow = Duration(seconds: 4);

  /// Maximum age the Whisper path will accept a stored pre-roll clip. Older
  /// than this (or absent) ⇒ no prepend, so a stale clip never bleeds into a
  /// later FAB-tap turn. Sized to the worst-case wake→record handoff latency.
  static const Duration wakeWordPreRollMaxAge = Duration(milliseconds: 2500);

  // ───────────────────────────────────────────────────────────────────────
  // Continuous conversation
  // ───────────────────────────────────────────────────────────────────────

  /// Hard ceiling on consecutive auto-re-listens (from continuation turns)
  /// without the user initiating a fresh listen. Bounds a misfiring
  /// clarify/confirm loop so it cannot run forever or drain the mic.
  /// Reset on every user-initiated listen and every endpoint.
  /// Redesign-overview §4.
  static const int maxConsecutiveRelistens = 5;
}
