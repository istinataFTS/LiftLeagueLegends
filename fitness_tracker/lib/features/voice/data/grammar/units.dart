/// Grammar data for spoken unit recognition.
///
/// Provides canonical weight unit resolution and rep-alias detection.
/// All keys are lowercase; callers must normalise before lookup.
abstract final class VoiceUnitGrammar {
  VoiceUnitGrammar._();

  static const String kg = 'kg';
  static const String lbs = 'lbs';

  /// Weight tokens that map to kilograms.
  static const Set<String> kgAliases = {
    'kg',
    'kgs',
    'kilo',
    'kilos',
    'kilogram',
    'kilograms',
    'k',
  };

  /// Weight tokens that map to pounds.
  static const Set<String> lbsAliases = {'lb', 'lbs', 'pound', 'pounds', 'p'};

  /// Tokens that indicate a repetition count (not weight).
  static const Set<String> repAliases = {
    'rep',
    'reps',
    'repetition',
    'repetitions',
    'time',
    'times',
    'x',
  };

  /// Returns [kg] or [lbs] for a known weight token, or null otherwise.
  static String? canonicalWeightUnit(String token) {
    final t = token.trim().toLowerCase();
    if (kgAliases.contains(t)) return kg;
    if (lbsAliases.contains(t)) return lbs;
    return null;
  }

  /// Returns true if [token] is a recognised repetition marker.
  static bool isRepAlias(String token) =>
      repAliases.contains(token.trim().toLowerCase());
}
