import '../../../data/grammar/numbers.dart';
import '../../../data/grammar/nutrition_phrases.dart';
import '../../../data/grammar/verbs.dart';
import '../parsed.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Prefix fillers to skip before the verb.
const _prefixFillers = {'i', "i've", 'ive', 'just', 'already', 'now'};

/// Tokens to skip when building the meal name (articles / determiners).
const _nameSkip = {'a', 'an', 'the', 'my', 'some', 'of'};

/// Returns true if the token is numeric (excluding "a" article).
bool _isNumeric(String token) {
  if (token == 'a') return false;
  return VoiceNumberGrammar.parseSingle(token) != null;
}

/// Tries to scan [tokens] for a number followed by an optional macro keyword.
/// Returns the numeric value or null.
double? _scanForNumber(List<String> tokens) {
  for (int i = 0; i < tokens.length; i++) {
    final v = VoiceNumberGrammar.parseSingle(tokens[i]);
    if (v != null && tokens[i] != 'a') return v.toDouble();
  }
  return null;
}

/// Tries to extract macro fields from [normed] text.
/// Scans for patterns like "200 calories", "30 grams protein", "10g fat".
({double? calories, double? protein, double? carbs, double? fat})
_extractMacros(String normed) {
  double? calories;
  double? protein;
  double? carbs;
  double? fat;

  final tokens = normed.split(' ');
  for (int i = 0; i < tokens.length; i++) {
    final v = VoiceNumberGrammar.parseSingle(tokens[i]);
    if (v == null || tokens[i] == 'a') continue;

    // Look ahead for macro keyword.
    for (int j = i + 1; j <= i + 2 && j < tokens.length; j++) {
      final kw = tokens[j];
      if (kw == 'calories' || kw == 'calorie' || kw == 'cal' || kw == 'kcal') {
        calories = v.toDouble();
        break;
      }
      if (kw == 'protein' || kw == 'proteins') {
        protein = v.toDouble();
        break;
      }
      if (kw == 'carbs' ||
          kw == 'carb' ||
          kw == 'carbohydrate' ||
          kw == 'carbohydrates') {
        carbs = v.toDouble();
        break;
      }
      if (kw == 'fat' || kw == 'fats') {
        fat = v.toDouble();
        break;
      }
    }
  }

  return (calories: calories, protein: protein, carbs: carbs, fat: fat);
}

// ---------------------------------------------------------------------------
// Delete nutrition log
// ---------------------------------------------------------------------------

/// Matches utterances that ask to delete the most-recently logged nutrition entry.
///
/// Examples:
///   "delete my last meal"         "remove the last nutrition log"
///   "undo my last food entry"     "cancel the last nutrition entry"
///   "erase my last meal log"      "delete the food I just logged"
ParsedIntent? matchDeleteNutrition(String normed) {
  final tokens = normed.split(' ');
  final hasDeleteVerb = tokens.any(VoiceVerbGrammar.deleteVerbs.contains);
  if (!hasDeleteVerb) return null;

  // Must reference a nutrition-related concept.
  final hasNutritionRef =
      normed.contains('meal') ||
      normed.contains('nutrition') ||
      normed.contains('calorie') ||
      normed.contains('food') ||
      normed.contains('ate') ||
      normed.contains('eaten') ||
      normed.contains('logged food') ||
      normed.contains('log') ||
      normed.contains('entry') ||
      normed.contains('intake');
  if (!hasNutritionRef) return null;

  return const ParsedDeleteNutrition();
}

// ---------------------------------------------------------------------------
// Edit nutrition log
// ---------------------------------------------------------------------------

/// Nutrition-domain words that anchor an edit to the nutrition log (vs a
/// workout set). At least one must be present for an edit to match here.
const _nutritionRefWords = {
  'meal',
  'nutrition',
  'calorie',
  'calories',
  'cal',
  'kcal',
  'food',
  'protein',
  'proteins',
  'carb',
  'carbs',
  'carbohydrate',
  'carbohydrates',
  'fat',
  'fats',
  'macro',
  'macros',
  'ate',
  'eaten',
};

/// Extracts macro fields for an *edit*, where the macro keyword may appear
/// either before the number ("calories to 300", "protein to 40") or after it
/// ("300 calories", "40 grams of protein"). For each macro type the value is
/// the number positionally closest to the keyword; ties resolve to the
/// earlier number so "200 calories 20 protein" maps correctly.
({double? calories, double? protein, double? carbs, double? fat})
_extractEditMacros(List<String> tokens) {
  final numbers = <({int index, double value})>[];
  for (int i = 0; i < tokens.length; i++) {
    if (tokens[i] == 'a') continue;
    final v = VoiceNumberGrammar.parseSingle(tokens[i]);
    if (v != null) numbers.add((index: i, value: v.toDouble()));
  }

  double? nearest(Set<String> keywords) {
    for (int i = 0; i < tokens.length; i++) {
      if (!keywords.contains(tokens[i])) continue;
      ({int index, double value})? pick;
      int? pickDist;
      for (final n in numbers) {
        final dist = (n.index - i).abs();
        if (pick == null ||
            dist < pickDist! ||
            (dist == pickDist && n.index < pick.index)) {
          pick = n;
          pickDist = dist;
        }
      }
      if (pick != null) return pick.value;
    }
    return null;
  }

  return (
    calories: nearest({'calories', 'calorie', 'cal', 'kcal'}),
    protein: nearest({'protein', 'proteins'}),
    carbs: nearest({'carbs', 'carb', 'carbohydrate', 'carbohydrates'}),
    fat: nearest({'fat', 'fats'}),
  );
}

/// Matches utterances that correct the most-recently logged nutrition entry.
/// Only non-null macro fields are returned; the coordinator applies them as a
/// patch over the existing log.
///
/// Examples:
///   "change the calories to 300"        "update protein to 40 grams"
///   "fix my last meal to 250 calories"  "actually it was 300 calories"
///   "the carbs should be 50"            "i meant 40 grams of protein"
ParsedIntent? matchEditNutrition(String normed) {
  final tokens = normed.split(' ');

  // Delete commands are handled by matchDeleteNutrition.
  if (tokens.any(VoiceVerbGrammar.deleteVerbs.contains)) return null;

  // Queries ("what are my macros") are not edits.
  if (tokens.isNotEmpty && VoiceVerbGrammar.queryWords.contains(tokens[0])) {
    return null;
  }

  // Must reference the nutrition domain to avoid stealing workout-set edits.
  final hasNutritionRef = _nutritionRefWords.any(
    (kw) => RegExp(r'\b' + kw + r'\b').hasMatch(normed),
  );
  if (!hasNutritionRef) return null;

  final hasEditVerb = tokens.any(VoiceVerbGrammar.editVerbs.contains);
  final hasImplicitEdit =
      normed.contains('actually') ||
      normed.contains('i meant') ||
      normed.contains('i mean') ||
      normed.contains('wrong') ||
      normed.contains('should be') ||
      normed.contains('was actually') ||
      normed.contains('mistake');
  if (!hasEditVerb && !hasImplicitEdit) return null;

  final macros = _extractEditMacros(tokens);
  double? calories = macros.calories;

  // No explicit macro keyword matched a number — treat a lone number as the
  // new calorie value (e.g. "change my last meal to 300").
  if (calories == null &&
      macros.protein == null &&
      macros.carbs == null &&
      macros.fat == null) {
    calories = _scanForNumber(tokens);
  }

  // Edit verb present but no numeric value at all — ambiguous; do not match.
  if (calories == null &&
      macros.protein == null &&
      macros.carbs == null &&
      macros.fat == null) {
    return null;
  }

  return ParsedEditNutrition(
    calories: calories,
    proteinGrams: macros.protein,
    carbsGrams: macros.carbs,
    fatGrams: macros.fat,
  );
}

// ---------------------------------------------------------------------------
// Log nutrition
// ---------------------------------------------------------------------------

/// Matches utterances that ask to log a new nutrition entry.
///
/// Recognised patterns:
///   [verb?] [meal_name] [number] [calories|cal|kcal]? [macros...]
///   [verb?] [meal_name] [grams consumed]?
///
/// Examples:
///   "log oats 300 calories"
///   "add chicken breast 200 calories 30 grams protein"
///   "i ate oats 300 cal 10 protein 50 carbs"
///   "log greek yogurt 150 calories"
ParsedIntent? matchLogNutrition(String normed) {
  final tokens = normed.split(' ');
  if (tokens.length < 2) return null;

  // Do not match delete commands (e.g. "delete my last meal").
  if (tokens.any(VoiceVerbGrammar.deleteVerbs.contains)) return null;

  // Do not match query utterances (e.g. "what are my macros", "how many calories").
  // Query words at position 0 mean the user is asking, not logging.
  if (tokens.isNotEmpty && VoiceVerbGrammar.queryWords.contains(tokens[0])) {
    return null;
  }

  // Must contain at least one nutrition marker to distinguish from workout log.
  if (!VoiceNutritionPhraseGrammar.hasLogMarker(normed)) return null;

  int i = 0;

  // Skip personal pronoun fillers.
  while (i < tokens.length && _prefixFillers.contains(tokens[i])) {
    i++;
  }

  // Accept eating-related verbs: "ate", "had", "eat", "drink", "drank".
  const eatVerbs = {'ate', 'had', 'eat', 'eaten', 'drink', 'drank', 'drinking'};
  final isEatVerb = i < tokens.length && eatVerbs.contains(tokens[i]);

  // Accept standard log verbs.
  final isLogVerb =
      i < tokens.length && VoiceVerbGrammar.logVerbs.contains(tokens[i]);

  if (isLogVerb || isEatVerb) i++;

  // Skip a second filler after the verb ("i just ate").
  if (i < tokens.length && _prefixFillers.contains(tokens[i])) i++;
  if (i < tokens.length &&
      (VoiceVerbGrammar.logVerbs.contains(tokens[i]) ||
          eatVerbs.contains(tokens[i]))) {
    i++;
  }

  // Skip articles.
  while (i < tokens.length && _nameSkip.contains(tokens[i])) {
    i++;
  }

  if (i >= tokens.length) return null;

  // Collect meal name tokens until the first numeric token.
  // Macro markers (e.g. "protein", "calories") are NOT stopped on — they
  // can legitimately appear in food names ("protein shake", "whey protein").
  // Numbers are the reliable delimiter between name and values.
  final mealTokens = <String>[];
  while (i < tokens.length) {
    final token = tokens[i];
    if (_nameSkip.contains(token)) {
      i++;
      continue;
    }
    if (_isNumeric(token)) break;
    mealTokens.add(token);
    i++;
  }

  if (mealTokens.isEmpty) return null;
  final mealName = mealTokens.join(' ');

  // Extract macros from the remaining text.
  final remaining = tokens.sublist(i).join(' ');
  final macros = _extractMacros(remaining);

  // Also try first standalone number as calories if no explicit label found.
  double? calories = macros.calories;
  if (calories == null) {
    final firstNum = _scanForNumber(tokens.sublist(i));
    if (firstNum != null) calories = firstNum;
  }

  return ParsedLogNutrition(
    mealName: mealName,
    calories: calories,
    proteinGrams: macros.protein,
    carbsGrams: macros.carbs,
    fatGrams: macros.fat,
  );
}
