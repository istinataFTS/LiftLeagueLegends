/// Single source of truth for mapping any pre-v26 muscle key (granular or
/// simple) to the canonical 18-key taxonomy.
///
/// The two legacy vocabularies that coexisted before v26:
///   • *Granular* — 22 keys used by seed data and [MuscleStimulus] constants
///     (e.g. `'front-delts'`, `'mid-chest'`, `'middle-traps'`).
///   • *Simple* — 15 keys used by the exercise edit dialog and custom exercises
///     (e.g. `'shoulder'`, `'chest'`, `'hamstring'`).
///
/// Use [canonicalizeMuscleKey] rather than the raw map so that
/// case/whitespace normalisation is handled automatically.
class LegacyMuscleGroupMap {
  LegacyMuscleGroupMap._();

  /// Maps every recognised legacy key to its canonical equivalent.
  ///
  /// Canonical keys are not listed here; [canonicalizeMuscleKey] returns them
  /// unchanged via the `?? raw` fallback.
  ///
  /// GATE-1 resolutions (traps / neck):
  ///   `'traps'` → `'lower-traps'`  (the larger merged region).
  ///   `'neck'`  → `'upper-traps'`  (neck PNG is rendered under upper-traps).
  static const Map<String, String> legacyToCanonical = <String, String>{
    // ── Granular → canonical ────────────────────────────────────────────────
    'front-delts': 'shoulders',
    'side-delts': 'shoulders',
    'rear-delts': 'rear-delts',
    'upper-traps': 'upper-traps',
    'middle-traps': 'lower-traps',
    'lower-traps': 'lower-traps',
    'upper-chest': 'chest',
    'mid-chest': 'chest',
    'lower-chest': 'chest',
    'lats': 'lats',
    'biceps': 'biceps',
    'triceps': 'triceps',
    'forearms': 'forearms',
    'abs': 'abs',
    'obliques': 'obliques',
    'lovehandles': 'lovehandles',
    'lower-back': 'lower-back',
    'glutes': 'glutes',
    'hipadductors': 'hipadductors',
    'quads': 'quads',
    'hamstrings': 'hamstrings',
    'calves': 'calves',
    // ── Simple → canonical ──────────────────────────────────────────────────
    'shoulder': 'shoulders',
    'traps': 'lower-traps',
    'neck': 'upper-traps',
    'chest': 'chest',
    'lower back': 'lower-back',
    'hamstring': 'hamstrings',
  };

  /// Returns the canonical muscle key for [raw], normalising case and
  /// whitespace first.
  ///
  /// Already-canonical keys are returned unchanged (identity mapping via the
  /// `?? key` fallback). Completely unknown keys are also returned unchanged so
  /// callers do not need a null-check.
  static String canonicalizeMuscleKey(String raw) {
    final String key = raw.trim().toLowerCase();
    return legacyToCanonical[key] ?? key;
  }
}
