import 'package:fitness_tracker/features/voice/data/grammar/nutrition_phrases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceNutritionPhraseGrammar.hasLogMarker', () {
    test('detects calorie markers', () {
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker('log 200 calories'),
        isTrue,
      );
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('300 cal'), isTrue);
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('400 kcal'), isTrue);
    });

    test('detects macro markers', () {
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker('30 grams of protein'),
        isTrue,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker('log some carbs'),
        isTrue,
      );
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('add fat'), isTrue);
    });

    test('detects eating markers', () {
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('I ate oats'), isTrue);
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('had a meal'), isTrue);
    });

    test('detects food and meal markers', () {
      expect(VoiceNutritionPhraseGrammar.hasLogMarker('log my meal'), isTrue);
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker('add food entry'),
        isTrue,
      );
    });

    test('does not match workout-only utterances', () {
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker(
          'log bench press 80 kg 10 reps',
        ),
        isFalse,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasLogMarker('delete my last set'),
        isFalse,
      );
    });

    test('returns false for empty string', () {
      expect(VoiceNutritionPhraseGrammar.hasLogMarker(''), isFalse);
    });
  });

  group('VoiceNutritionPhraseGrammar.hasMacroQueryTrigger', () {
    test('detects macro keyword', () {
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger("what are my macros"),
        isTrue,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger("show my nutrition"),
        isTrue,
      );
    });

    test('detects calorie query', () {
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger(
          "how many calories today",
        ),
        isTrue,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger("calorie total"),
        isTrue,
      );
    });

    test('detects protein/carb/fat queries', () {
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger(
          "how much protein did I have",
        ),
        isTrue,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger("check my carbs"),
        isTrue,
      );
    });

    test('does not match unrelated utterances', () {
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger('log bench press'),
        isFalse,
      );
      expect(
        VoiceNutritionPhraseGrammar.hasMacroQueryTrigger('delete my last set'),
        isFalse,
      );
    });

    test('returns false for empty string', () {
      expect(VoiceNutritionPhraseGrammar.hasMacroQueryTrigger(''), isFalse);
    });
  });
}
