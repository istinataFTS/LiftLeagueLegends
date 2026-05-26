import 'package:fitness_tracker/features/voice/data/grammar/time_phrases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceTimePhraseGrammar.isToday', () {
    test('recognises today phrases', () {
      for (final phrase in [
        'today',
        'now',
        'tonight',
        'this morning',
        'this afternoon',
        'this evening',
        'right now',
        'just now',
      ]) {
        expect(
          VoiceTimePhraseGrammar.isToday(phrase),
          isTrue,
          reason: '"$phrase" should be today',
        );
      }
    });

    test('rejects non-today phrases', () {
      expect(VoiceTimePhraseGrammar.isToday('yesterday'), isFalse);
      expect(VoiceTimePhraseGrammar.isToday('this week'), isFalse);
      expect(VoiceTimePhraseGrammar.isToday('bench press'), isFalse);
    });

    test('is case-insensitive and trims', () {
      expect(VoiceTimePhraseGrammar.isToday('TODAY'), isTrue);
      expect(VoiceTimePhraseGrammar.isToday(' today '), isTrue);
    });
  });

  group('VoiceTimePhraseGrammar.isThisWeek', () {
    test('recognises this-week phrases', () {
      for (final phrase in [
        'this week',
        'weekly',
        'week',
        'past week',
        'last seven days',
        'last 7 days',
        'past 7 days',
        'past seven days',
      ]) {
        expect(
          VoiceTimePhraseGrammar.isThisWeek(phrase),
          isTrue,
          reason: '"$phrase" should be this week',
        );
      }
    });

    test('rejects non-week phrases', () {
      expect(VoiceTimePhraseGrammar.isThisWeek('today'), isFalse);
      expect(VoiceTimePhraseGrammar.isThisWeek('yesterday'), isFalse);
    });
  });

  group('VoiceTimePhraseGrammar.isYesterday', () {
    test('recognises yesterday', () {
      expect(VoiceTimePhraseGrammar.isYesterday('yesterday'), isTrue);
    });

    test('is case-insensitive', () {
      expect(VoiceTimePhraseGrammar.isYesterday('Yesterday'), isTrue);
    });

    test('rejects non-yesterday phrases', () {
      expect(VoiceTimePhraseGrammar.isYesterday('today'), isFalse);
      expect(VoiceTimePhraseGrammar.isYesterday('this week'), isFalse);
    });
  });
}
