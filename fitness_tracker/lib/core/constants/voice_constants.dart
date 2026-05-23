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

  /// STT recognition timeout ΓÇö drops the partial transcript if the user
  /// has stopped speaking for this long. Tuned for short workout-log
  /// utterances ("log bench, 80 by 10") rather than free-form prose.
  static const Duration sttSilenceTimeout = Duration(seconds: 2);

  /// HTTP timeout for the `voice-chat` Edge Function call. Generous
  /// enough for GPT-4o-mini (typically 1–3 s) plus network latency,
  /// but short enough to avoid hanging indefinitely on poor connections.
  static const Duration voiceChatHttpTimeout = Duration(seconds: 30);

  /// Hard upper bound for STT listening ΓÇö even if the user keeps
  /// talking, force a stop at this duration to bound costs and UX.
  ///
  /// Raised from 10 s to 15 s to accommodate multi-field edit utterances
  /// (e.g. "change carbs to 60, fat to 15") without forcing the user to
  /// dictate everything in one breath. 15 s is still tight enough to bound
  /// per-utterance audio cost and discourage 30 s rambles.
  static const Duration sttListenTimeout = Duration(seconds: 15);
}
