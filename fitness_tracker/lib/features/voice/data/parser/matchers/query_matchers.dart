import '../../../data/grammar/nutrition_phrases.dart';
import '../parsed.dart';

// ---------------------------------------------------------------------------
// Weekly volume query
// ---------------------------------------------------------------------------

/// Trigger phrases for the "weekly volume" query.
/// These are lowercased whole-utterance fragments or keywords.
const _weeklyVolumeTriggers = {
  'weekly volume',
  'week volume',
  "this week's volume",
  'volume this week',
  'volume for the week',
  'my weekly volume',
  'how many sets this week',
  'how many sets did i do this week',
  'how many sets have i done this week',
  'sets this week',
  'sets for the week',
  "week's sets",
  'total sets this week',
  'set count this week',
  'workout volume',
  'training volume',
  'training volume this week',
  'volume',
};

/// Matches utterances that ask for the weekly workout volume.
///
/// Examples:
///   "what is my weekly volume"
///   "how many sets did I do this week"
///   "show my training volume"
ParsedIntent? matchQueryWeeklyVolume(String normed) {
  // Exact phrase match first.
  if (_weeklyVolumeTriggers.contains(normed)) {
    return const ParsedQueryWeeklyVolume();
  }

  // Substring match for key phrases.
  if (_weeklyVolumeTriggers.any((t) => normed.contains(t))) {
    return const ParsedQueryWeeklyVolume();
  }

  // Fallback: "volume" + "week" anywhere in the utterance.
  if (normed.contains('volume') && normed.contains('week')) {
    return const ParsedQueryWeeklyVolume();
  }

  // "how many sets" + weekly context.
  if ((normed.contains('how many sets') || normed.contains('how many reps')) &&
      (normed.contains('week') || normed.contains('weekly'))) {
    return const ParsedQueryWeeklyVolume();
  }

  return null;
}

// ---------------------------------------------------------------------------
// Daily macros query
// ---------------------------------------------------------------------------

/// Matches utterances that ask for today's macro / calorie totals.
///
/// Examples:
///   "what are my macros"
///   "how many calories today"
///   "show my nutrition for today"
ParsedIntent? matchQueryDailyMacros(String normed) {
  if (VoiceNutritionPhraseGrammar.hasMacroQueryTrigger(normed)) {
    return const ParsedQueryDailyMacros();
  }
  return null;
}

// ---------------------------------------------------------------------------
// Recent sets query
// ---------------------------------------------------------------------------

/// Trigger phrases for the "recent sets" query.
const _recentSetsTriggers = {
  'recent sets',
  'last sets',
  'latest sets',
  'my recent sets',
  'my last sets',
  'recent workout',
  'recent workouts',
  'last workout',
  'latest workout',
  'what did i do',
  'what have i done',
  'what have i logged',
  'what did i log',
  'recent exercises',
  'last exercises',
  'show my sets',
  'show my workout',
  'show my recent',
  'what sets',
};

/// Matches utterances that ask to see recently logged workout sets.
///
/// Examples:
///   "show my recent sets"
///   "what did I do today"
///   "show my last workout"
ParsedIntent? matchQueryRecentSets(String normed) {
  // Exact phrase match.
  if (_recentSetsTriggers.contains(normed)) {
    return const ParsedQueryRecentSets();
  }

  // Substring match.
  if (_recentSetsTriggers.any((t) => normed.contains(t))) {
    return const ParsedQueryRecentSets();
  }

  // Fallback: "what" + "exercise" / "set" / "workout" + time reference.
  if ((normed.contains('what') ||
          normed.contains('show') ||
          normed.contains('tell')) &&
      (normed.contains('exercise') ||
          normed.contains('set') ||
          normed.contains('workout') ||
          normed.contains('lift') ||
          normed.contains('train'))) {
    return const ParsedQueryRecentSets();
  }

  return null;
}
