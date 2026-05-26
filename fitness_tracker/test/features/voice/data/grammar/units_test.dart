import 'package:fitness_tracker/features/voice/data/grammar/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceUnitGrammar.canonicalWeightUnit', () {
    test('recognises kg aliases', () {
      for (final alias in [
        'kg',
        'kgs',
        'kilo',
        'kilos',
        'kilogram',
        'kilograms',
        'k',
      ]) {
        expect(
          VoiceUnitGrammar.canonicalWeightUnit(alias),
          VoiceUnitGrammar.kg,
          reason: '"$alias" should map to kg',
        );
      }
    });

    test('recognises lbs aliases', () {
      for (final alias in ['lb', 'lbs', 'pound', 'pounds', 'p']) {
        expect(
          VoiceUnitGrammar.canonicalWeightUnit(alias),
          VoiceUnitGrammar.lbs,
          reason: '"$alias" should map to lbs',
        );
      }
    });

    test('returns null for unknown tokens', () {
      expect(VoiceUnitGrammar.canonicalWeightUnit('reps'), isNull);
      expect(VoiceUnitGrammar.canonicalWeightUnit('bench'), isNull);
      expect(VoiceUnitGrammar.canonicalWeightUnit(''), isNull);
    });

    test('is case-insensitive', () {
      expect(VoiceUnitGrammar.canonicalWeightUnit('KG'), VoiceUnitGrammar.kg);
      expect(VoiceUnitGrammar.canonicalWeightUnit('LBS'), VoiceUnitGrammar.lbs);
    });

    test('trims whitespace', () {
      expect(VoiceUnitGrammar.canonicalWeightUnit(' kg '), VoiceUnitGrammar.kg);
    });
  });

  group('VoiceUnitGrammar.isRepAlias', () {
    test('recognises rep tokens', () {
      for (final alias in [
        'rep',
        'reps',
        'repetition',
        'repetitions',
        'time',
        'times',
        'x',
      ]) {
        expect(
          VoiceUnitGrammar.isRepAlias(alias),
          isTrue,
          reason: '"$alias" should be rep alias',
        );
      }
    });

    test('returns false for non-rep tokens', () {
      expect(VoiceUnitGrammar.isRepAlias('kg'), isFalse);
      expect(VoiceUnitGrammar.isRepAlias('bench'), isFalse);
    });

    test('is case-insensitive', () {
      expect(VoiceUnitGrammar.isRepAlias('REPS'), isTrue);
    });
  });
}
