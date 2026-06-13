import 'dart:typed_data';

/// A captured pre-roll audio clip — the raw PCM16 the wake-word engine held in
/// its rolling ring buffer at the moment the microphone was released for the
/// STT handoff.
///
/// Prepended to the Whisper upload so the words a user speaks *immediately
/// after* the wake word ("Thomas, log me bench press") are not lost in the
/// wake→STT mic-handoff gap. Pure value type — no Flutter, no platform deps.
class PreRollClip {
  const PreRollClip({
    required this.pcm16,
    required this.sampleRate,
    required this.capturedAt,
  });

  /// Little-endian PCM16 mono samples, with **no** WAV/RIFF header.
  final Uint8List pcm16;

  /// Sample rate of [pcm16] in Hz (16 kHz mono for the wake engine).
  final int sampleRate;

  /// Wall-clock instant the clip was captured. Used by the consumer to reject
  /// stale clips (see [VoicePreRollStore.take]).
  final DateTime capturedAt;

  /// True when there are no samples to prepend.
  bool get isEmpty => pcm16.isEmpty;
}

/// Single-slot hand-off buffer between the wake-word engine (producer) and the
/// Whisper STT path (consumer). Holds at most one recent [PreRollClip].
///
/// Both sides are DI singletons; this store is the *only* coupling between
/// them, deliberately kept tiny so it is trivially unit-testable and carries no
/// platform dependencies. It intentionally does **not** change the
/// [VoiceSttService] contract — threading audio through the wake-detection
/// event and the bloc would do that (Option B); a shared store keeps the audio
/// entirely inside the data layer.
abstract class VoicePreRollStore {
  /// Store the latest pre-roll, replacing any clip already held. Producer side.
  void put(PreRollClip clip);

  /// Return and clear the stored clip **iff** it was captured within [maxAge]
  /// (and is non-empty). A clip older than [maxAge] — or none at all — yields
  /// `null`, and the slot is cleared either way, so a stale clip can never
  /// bleed into a later FAB-tap (non-wake) turn. Consumer side.
  PreRollClip? take({required Duration maxAge});

  /// Drop any stored clip without consuming it (e.g. on a cancelled turn).
  void clear();
}
