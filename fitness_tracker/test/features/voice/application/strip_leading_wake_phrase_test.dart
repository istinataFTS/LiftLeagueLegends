import 'package:fitness_tracker/features/voice/application/voice_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Mirror WakeWordPreset.thomas.acceptedPhrases. Hardcoded rather than
  // imported because this test exists to lock the helper's behaviour, not the
  // current preset wiring.
  const phrases = <String>{'THOMAS', 'HEY THOMAS'};

  group('stripLeadingWakePhrase', () {
    test('strips a leading wake phrase + comma', () {
      expect(
        stripLeadingWakePhrase('Thomas, log me bench press', phrases),
        'log me bench press',
      );
    });

    test('is case-insensitive', () {
      expect(
        stripLeadingWakePhrase('THOMAS log me bench press', phrases),
        'log me bench press',
      );
      expect(
        stripLeadingWakePhrase('thomas log me bench press', phrases),
        'log me bench press',
      );
    });

    test('prefers the longest matching phrase', () {
      expect(
        stripLeadingWakePhrase('Hey Thomas, log me bench press', phrases),
        'log me bench press',
      );
    });

    test('does not strip when the wake word appears mid-sentence', () {
      expect(
        stripLeadingWakePhrase('log the thomas bench press', phrases),
        'log the thomas bench press',
      );
    });

    test('does not strip a word that merely starts with the phrase', () {
      expect(
        stripLeadingWakePhrase("thomas's bench press", phrases),
        "thomas's bench press",
      );
    });

    test('strips trailing punctuation + extra whitespace', () {
      expect(
        stripLeadingWakePhrase('Thomas... log me bench press', phrases),
        'log me bench press',
      );
      expect(
        stripLeadingWakePhrase('Thomas.   log me bench press', phrases),
        'log me bench press',
      );
    });

    test('returns the empty string when only the wake phrase was spoken', () {
      expect(stripLeadingWakePhrase('Thomas', phrases), '');
      expect(stripLeadingWakePhrase('Thomas.', phrases), '');
      expect(stripLeadingWakePhrase('   Thomas   ', phrases), '');
    });

    test('returns the input untouched when no phrase is configured', () {
      expect(
        stripLeadingWakePhrase('thomas log me bench press', const <String>{}),
        'thomas log me bench press',
      );
    });

    test('preserves the rest of the transcript verbatim', () {
      expect(
        stripLeadingWakePhrase(
          'Thomas, log 60 kg bench press for 8 reps',
          phrases,
        ),
        'log 60 kg bench press for 8 reps',
      );
    });
  });
}
