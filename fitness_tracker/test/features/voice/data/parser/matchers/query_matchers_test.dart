import 'package:fitness_tracker/features/voice/data/parser/intent_parser.dart';
import 'package:fitness_tracker/features/voice/data/parser/matchers/query_matchers.dart';
import 'package:fitness_tracker/features/voice/data/parser/parsed.dart';
import 'package:flutter_test/flutter_test.dart';

T? _match<T extends ParsedIntent>(
  ParsedIntent? Function(String) matcher,
  String text,
) {
  final result = matcher(IntentParser.normalise(text));
  if (result is T) return result;
  return null;
}

void main() {
  // =========================================================================
  // matchQueryWeeklyVolume
  // =========================================================================

  group('matchQueryWeeklyVolume', () {
    test('01 — what is my weekly volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'what is my weekly volume',
        ),
        isNotNull,
      );
    });

    test('02 — how many sets did i do this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'how many sets did i do this week',
        ),
        isNotNull,
      );
    });

    test('03 — show my training volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'show my training volume',
        ),
        isNotNull,
      );
    });

    test('04 — what is my volume this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'what is my volume this week',
        ),
        isNotNull,
      );
    });

    test('05 — weekly volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'weekly volume',
        ),
        isNotNull,
      );
    });

    test('06 — how many sets this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'how many sets this week',
        ),
        isNotNull,
      );
    });

    test('07 — sets this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'sets this week',
        ),
        isNotNull,
      );
    });

    test('08 — what is my training volume this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'what is my training volume this week',
        ),
        isNotNull,
      );
    });

    test('09 — tell me my weekly volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'tell me my weekly volume',
        ),
        isNotNull,
      );
    });

    test('10 — check my volume for the week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'check my volume for the week',
        ),
        isNotNull,
      );
    });

    test('11 — show weekly volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'show weekly volume',
        ),
        isNotNull,
      );
    });

    test('12 — volume this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'volume this week',
        ),
        isNotNull,
      );
    });

    test('13 — how many sets have i done this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'how many sets have i done this week',
        ),
        isNotNull,
      );
    });

    test('14 — total sets this week', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'total sets this week',
        ),
        isNotNull,
      );
    });

    test('15 — what\'s my volume', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          "what's my volume",
        ),
        isNotNull,
      );
    });

    // Negative cases.
    test('no match — macro query', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'what are my macros',
        ),
        isNull,
      );
    });

    test('no match — log utterance', () {
      expect(
        _match<ParsedQueryWeeklyVolume>(
          matchQueryWeeklyVolume,
          'log bench press 80 kg 10 reps',
        ),
        isNull,
      );
    });
  });

  // =========================================================================
  // matchQueryDailyMacros
  // =========================================================================

  group('matchQueryDailyMacros', () {
    test('01 — what are my macros', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'what are my macros',
        ),
        isNotNull,
      );
    });

    test('02 — how many calories today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'how many calories today',
        ),
        isNotNull,
      );
    });

    test('03 — show my nutrition', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'show my nutrition',
        ),
        isNotNull,
      );
    });

    test('04 — what is my protein today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'what is my protein today',
        ),
        isNotNull,
      );
    });

    test('05 — calorie total', () {
      expect(
        _match<ParsedQueryDailyMacros>(matchQueryDailyMacros, 'calorie total'),
        isNotNull,
      );
    });

    test('06 — how much protein did i have', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'how much protein did i have',
        ),
        isNotNull,
      );
    });

    test('07 — check my carbs', () {
      expect(
        _match<ParsedQueryDailyMacros>(matchQueryDailyMacros, 'check my carbs'),
        isNotNull,
      );
    });

    test('08 — what did i eat today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'what did i eat today',
        ),
        isNotNull,
      );
    });

    test('09 — show daily intake', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'show daily intake',
        ),
        isNotNull,
      );
    });

    test('10 — nutrition today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'nutrition today',
        ),
        isNotNull,
      );
    });

    test('11 — how many calories have i had', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'how many calories have i had',
        ),
        isNotNull,
      );
    });

    test('12 — daily macros', () {
      expect(
        _match<ParsedQueryDailyMacros>(matchQueryDailyMacros, 'daily macros'),
        isNotNull,
      );
    });

    test('13 — what are my calories for today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'what are my calories for today',
        ),
        isNotNull,
      );
    });

    test('14 — calorie count', () {
      expect(
        _match<ParsedQueryDailyMacros>(matchQueryDailyMacros, 'calorie count'),
        isNotNull,
      );
    });

    test('15 — what have i eaten today', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'what have i eaten today',
        ),
        isNotNull,
      );
    });

    // Negative cases.
    test('no match — weekly volume query', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'how many sets this week',
        ),
        isNull,
      );
    });

    test('no match — log utterance', () {
      expect(
        _match<ParsedQueryDailyMacros>(
          matchQueryDailyMacros,
          'log bench press 80 kg 10 reps',
        ),
        isNull,
      );
    });
  });

  // =========================================================================
  // matchQueryRecentSets
  // =========================================================================

  group('matchQueryRecentSets', () {
    test('01 — show my recent sets', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'show my recent sets',
        ),
        isNotNull,
      );
    });

    test('02 — what did i do today', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'what did i do today',
        ),
        isNotNull,
      );
    });

    test('03 — show my last workout', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'show my last workout',
        ),
        isNotNull,
      );
    });

    test('04 — recent sets', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'recent sets'),
        isNotNull,
      );
    });

    test('05 — what have i done today', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'what have i done today',
        ),
        isNotNull,
      );
    });

    test('06 — show my recent workout', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'show my recent workout',
        ),
        isNotNull,
      );
    });

    test('07 — what exercises did i log', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'what exercises did i log',
        ),
        isNotNull,
      );
    });

    test('08 — latest sets', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'latest sets'),
        isNotNull,
      );
    });

    test('09 — what did i log', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'what did i log'),
        isNotNull,
      );
    });

    test('10 — show my workout', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'show my workout'),
        isNotNull,
      );
    });

    test('11 — what sets did i do', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'what sets did i do',
        ),
        isNotNull,
      );
    });

    test('12 — recent exercises', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'recent exercises'),
        isNotNull,
      );
    });

    test('13 — show my sets', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'show my sets'),
        isNotNull,
      );
    });

    test('14 — what have i logged', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'what have i logged',
        ),
        isNotNull,
      );
    });

    test('15 — last exercises', () {
      expect(
        _match<ParsedQueryRecentSets>(matchQueryRecentSets, 'last exercises'),
        isNotNull,
      );
    });

    // Negative cases.
    test('no match — macro query', () {
      // "what did i eat" — contains "eat" not "exercise"/"set"/"workout"
      // but let's check that it's NOT matched as recentSets
      // Note: "what" + "eat" doesn't hit the fallback exercise/set/workout keywords
      final r = _match<ParsedQueryRecentSets>(
        matchQueryRecentSets,
        'what did i eat today',
      );
      // Could be null or not — "what" + no exercise keyword → should be null
      // but "what did i eat" contains no workout keyword so it should return null
      expect(r, isNull);
    });

    test('no match — log utterance', () {
      expect(
        _match<ParsedQueryRecentSets>(
          matchQueryRecentSets,
          'log bench press 80 kg 10 reps',
        ),
        isNull,
      );
    });
  });
}
