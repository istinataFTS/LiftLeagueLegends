import '../../../data/grammar/numbers.dart';
import '../../../data/grammar/units.dart';
import '../../../data/grammar/verbs.dart';
import '../parsed.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Tokens to skip as fillers before the verb (personal pronouns / adverbs).
const _prefixFillers = {'i', "i've", 'ive', 'just', 'already', 'now'};

/// Tokens to skip when building the exercise name (articles / prepositions).
const _nameSkip = {'a', 'an', 'the', 'my', 'some'};

/// Tokens that separate weight from reps (connectors).
const _connectors = {'by', 'x', 'for', 'and', 'times', 'at', 'of', 'to'};

/// Nutrition-domain words that indicate this utterance is NOT a workout set.
const _nutritionKeywords = {
  'meal',
  'nutrition',
  'calorie',
  'calories',
  'food',
  'protein',
  'carbs',
  'fat',
  'ate',
  'eaten',
  'drink',
  'drank',
  'macro',
  'macros',
  'grams',
  'gram',
  'serving',
};

bool _isNutritionContext(String normed) =>
    _nutritionKeywords.any((kw) => RegExp(r'\b' + kw + r'\b').hasMatch(normed));

/// Returns true if [token] should be treated as a numeric value in context.
/// Excludes 'a' (article) to avoid cutting exercise names at "a bench press".
bool _isNumeric(String token) {
  if (token == 'a') return false;
  return VoiceNumberGrammar.parseSingle(token) != null;
}

/// Tries to extract a weight + optional unit + reps from a token sub-list.
/// Returns null if both values cannot be found.
({double weight, int reps, String? unit})? _extractWeightReps(
  List<String> tokens,
) {
  double? weight;
  String? unit;
  int? reps;

  for (int i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    final numVal = VoiceNumberGrammar.parseSingle(token);

    if (numVal != null && token != 'a') {
      if (weight == null) {
        weight = numVal.toDouble();
        // Peek at next token for a weight unit.
        if (i + 1 < tokens.length) {
          final u = VoiceUnitGrammar.canonicalWeightUnit(tokens[i + 1]);
          if (u != null) {
            unit = u;
            i++;
          }
        }
      } else {
        // Skip rep alias immediately after this number (e.g. "10 reps").
        reps = numVal.toInt();
        break;
      }
      continue;
    }

    // Skip connectors and rep aliases silently.
    if (_connectors.contains(token) ||
        VoiceUnitGrammar.isRepAlias(token) ||
        _nameSkip.contains(token)) {
      continue;
    }
  }

  if (weight != null && reps != null) {
    return (weight: weight, reps: reps, unit: unit);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Delete workout set
// ---------------------------------------------------------------------------

/// Matches utterances that ask to delete the most-recently logged workout set.
///
/// Examples:
///   "delete my last set"        "remove the last set"
///   "undo last set"             "cancel that set"
///   "scratch that"              "never mind"
///   "erase my last workout"     "discard that"
ParsedIntent? matchDeleteWorkoutSet(String normed) {
  if (_isNutritionContext(normed)) return null;

  // Hard-coded short-form cancellation phrases.
  if (normed == 'scratch that' ||
      normed == 'never mind' ||
      normed == 'never mind that' ||
      normed == 'forget it' ||
      normed == 'forget that' ||
      normed == 'take that back') {
    return const ParsedDeleteWorkoutSet();
  }

  final tokens = normed.split(' ');
  final hasDeleteVerb = tokens.any(VoiceVerbGrammar.deleteVerbs.contains);
  if (!hasDeleteVerb) return null;

  // Must reference "set" / "workout" / "last" / "that" / "it".
  final hasRef =
      normed.contains('set') ||
      normed.contains('workout') ||
      normed.contains('that') ||
      normed.contains(' it') ||
      normed.contains('last');
  if (!hasRef) return null;

  return const ParsedDeleteWorkoutSet();
}

// ---------------------------------------------------------------------------
// Edit workout set
// ---------------------------------------------------------------------------

/// Matches utterances that ask to edit the most-recently logged workout set.
/// Only non-null fields are returned; the coordinator applies them as a patch.
///
/// Examples:
///   "change the weight to 90 kg"     "update reps to 8"
///   "fix my last set weight to 90"   "actually it was 90 kg"
///   "wrong weight should be 90 kg"   "i meant 90 kg not 80"
///   "set weight to 90 kg"            "reps should be 8"
ParsedIntent? matchEditWorkoutSet(String normed) {
  if (_isNutritionContext(normed)) return null;

  final tokens = normed.split(' ');

  final hasEditVerb = tokens.any(VoiceVerbGrammar.editVerbs.contains);

  // Implicit edit triggers — user is correcting without using an edit verb.
  final hasImplicitEdit =
      normed.contains('actually') ||
      normed.contains('i meant') ||
      normed.contains('i mean') ||
      normed.contains('wrong') ||
      normed.contains('should be') ||
      normed.contains('was actually') ||
      normed.contains('not ') ||
      normed.contains('mistake');

  if (!hasEditVerb && !hasImplicitEdit) return null;

  // Explicit edit verbs require a set/field reference to avoid false positives
  // (e.g. "change channel" should not match).
  // Implicit edits ("actually", "i meant", "mistake") carry enough context on
  // their own — a numeric value is sufficient.
  if (hasEditVerb && !hasImplicitEdit) {
    final hasSetOrField =
        normed.contains('set') ||
        normed.contains('workout') ||
        normed.contains('last') ||
        normed.contains('that') ||
        normed.contains('weight') ||
        normed.contains('reps') ||
        normed.contains('rep ');
    if (!hasSetOrField) return null;
  }

  // Extract new numeric values from the token stream.
  final extracted = _extractWeightReps(tokens);

  // Determine if only reps or only weight is mentioned.
  final repsOnly = normed.contains('rep') && !normed.contains('weight');
  final weightOnly = normed.contains('weight') && !normed.contains('rep');

  if (extracted != null) {
    if (repsOnly) {
      return ParsedEditWorkoutSet(reps: extracted.reps);
    }
    if (weightOnly) {
      return ParsedEditWorkoutSet(
        weight: extracted.weight,
        weightUnit: extracted.unit,
      );
    }
    return ParsedEditWorkoutSet(
      reps: extracted.reps,
      weight: extracted.weight,
      weightUnit: extracted.unit,
    );
  }

  // Single-value edits — only one number present.
  double? singleWeight;
  String? singleUnit;
  int? singleReps;

  for (int i = 0; i < tokens.length; i++) {
    final v = VoiceNumberGrammar.parseSingle(tokens[i]);
    if (v != null && tokens[i] != 'a') {
      if (i + 1 < tokens.length) {
        final u = VoiceUnitGrammar.canonicalWeightUnit(tokens[i + 1]);
        if (u != null) {
          singleWeight = v.toDouble();
          singleUnit = u;
          break;
        }
        if (VoiceUnitGrammar.isRepAlias(tokens[i + 1])) {
          singleReps = v.toInt();
          break;
        }
      }
      // Contextual fallback: if "weight" keyword present, treat number as weight.
      if (weightOnly) {
        singleWeight = v.toDouble();
        break;
      }
      if (repsOnly) {
        singleReps = v.toInt();
        break;
      }
    }
  }

  if (singleWeight != null || singleReps != null) {
    return ParsedEditWorkoutSet(
      weight: singleWeight,
      weightUnit: singleUnit,
      reps: singleReps,
    );
  }

  // Edit verb + set reference but no numeric value — ambiguous; do not match.
  return null;
}

// ---------------------------------------------------------------------------
// Log workout set
// ---------------------------------------------------------------------------

/// Matches utterances that ask to log a new workout set.
///
/// Expected pattern:
///   [verb?] [exercise_name] [weight] [unit?] [connector?] [reps] [rep_unit?]
///
/// Examples:
///   "log bench press 80 kg 10 reps"
///   "add squat 100 kg for 5"
///   "bench press 80 by 10"
///   "i did bench press eighty kilos ten"
///   "record deadlift 120 kg five reps"
ParsedIntent? matchLogWorkoutSet(String normed) {
  if (_isNutritionContext(normed)) return null;

  final tokens = normed.split(' ');
  if (tokens.length < 3) return null;

  int i = 0;

  // Skip prefix fillers ("i", "i've", "just", "already").
  while (i < tokens.length && _prefixFillers.contains(tokens[i])) {
    i++;
  }

  // Skip optional log verb.
  if (i < tokens.length && VoiceVerbGrammar.logVerbs.contains(tokens[i])) {
    i++;
  }

  // A second filler after the verb ("i just did").
  if (i < tokens.length && _prefixFillers.contains(tokens[i])) i++;
  if (i < tokens.length && VoiceVerbGrammar.logVerbs.contains(tokens[i])) i++;

  // Collect exercise name tokens until the first standalone numeric token.
  final exerciseTokens = <String>[];
  while (i < tokens.length) {
    final token = tokens[i];
    if (_nameSkip.contains(token)) {
      i++;
      continue;
    }
    if (_isNumeric(token)) break;
    exerciseTokens.add(token);
    i++;
  }

  if (exerciseTokens.isEmpty) return null;
  final exerciseName = exerciseTokens.join(' ');

  // Extract weight + reps from the remaining tokens.
  final rest = tokens.sublist(i);
  final extracted = _extractWeightReps(rest);
  if (extracted == null) return null;

  return ParsedLogWorkoutSet(
    exerciseName: exerciseName,
    reps: extracted.reps,
    weight: extracted.weight,
    weightUnit: extracted.unit,
  );
}
