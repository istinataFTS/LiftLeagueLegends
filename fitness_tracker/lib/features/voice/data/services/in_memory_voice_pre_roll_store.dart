import '../../../../core/time/clock.dart';
import '../../../../domain/services/voice_pre_roll_store.dart';

/// In-memory [VoicePreRollStore] holding at most one [PreRollClip].
///
/// TTL logic reads "now" from an injected [Clock] so age checks are
/// deterministic under test (a `FakeClock` can be advanced past the maxAge
/// boundary without real waiting).
class InMemoryVoicePreRollStore implements VoicePreRollStore {
  InMemoryVoicePreRollStore({required Clock clock}) : _clock = clock;

  final Clock _clock;
  PreRollClip? _clip;

  @override
  void put(PreRollClip clip) => _clip = clip;

  @override
  PreRollClip? take({required Duration maxAge}) {
    final clip = _clip;
    // Single-shot: the slot is always cleared on read, so a clip can be
    // consumed at most once and never lingers for an unrelated later turn.
    _clip = null;
    if (clip == null || clip.isEmpty) return null;
    final age = _clock.now().difference(clip.capturedAt);
    if (age.isNegative || age > maxAge) return null;
    return clip;
  }

  @override
  void clear() => _clip = null;
}
