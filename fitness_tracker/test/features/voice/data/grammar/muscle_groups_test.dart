import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';
import 'package:fitness_tracker/features/voice/data/grammar/muscle_groups.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceMuscleGroupGrammar.resolve', () {
    test('resolves chest aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('chest'), MuscleStimulus.midChest);
      expect(VoiceMuscleGroupGrammar.resolve('pecs'), MuscleStimulus.midChest);
      expect(
        VoiceMuscleGroupGrammar.resolve('upper chest'),
        MuscleStimulus.upperChest,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('lower chest'),
        MuscleStimulus.lowerChest,
      );
    });

    test('resolves back aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('back'), MuscleStimulus.lats);
      expect(VoiceMuscleGroupGrammar.resolve('lats'), MuscleStimulus.lats);
      expect(VoiceMuscleGroupGrammar.resolve('lat'), MuscleStimulus.lats);
    });

    test('resolves shoulder aliases', () {
      expect(
        VoiceMuscleGroupGrammar.resolve('shoulders'),
        MuscleStimulus.sideDelts,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('delts'),
        MuscleStimulus.sideDelts,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('front delts'),
        MuscleStimulus.frontDelts,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('rear delts'),
        MuscleStimulus.rearDelts,
      );
    });

    test('resolves arm aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('biceps'), MuscleStimulus.biceps);
      expect(
        VoiceMuscleGroupGrammar.resolve('triceps'),
        MuscleStimulus.triceps,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('forearms'),
        MuscleStimulus.forearms,
      );
    });

    test('resolves leg aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('legs'), MuscleStimulus.quads);
      expect(VoiceMuscleGroupGrammar.resolve('quads'), MuscleStimulus.quads);
      expect(
        VoiceMuscleGroupGrammar.resolve('hamstrings'),
        MuscleStimulus.hamstrings,
      );
      expect(VoiceMuscleGroupGrammar.resolve('glutes'), MuscleStimulus.glutes);
      expect(VoiceMuscleGroupGrammar.resolve('calves'), MuscleStimulus.calves);
    });

    test('resolves core aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('abs'), MuscleStimulus.abs);
      expect(VoiceMuscleGroupGrammar.resolve('core'), MuscleStimulus.abs);
      expect(
        VoiceMuscleGroupGrammar.resolve('obliques'),
        MuscleStimulus.obliques,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('lower back'),
        MuscleStimulus.lowerBack,
      );
    });

    test('resolves trap aliases', () {
      expect(
        VoiceMuscleGroupGrammar.resolve('traps'),
        MuscleStimulus.upperTraps,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('middle traps'),
        MuscleStimulus.middleTraps,
      );
      expect(
        VoiceMuscleGroupGrammar.resolve('lower traps'),
        MuscleStimulus.lowerTraps,
      );
    });

    test('returns null for unknown aliases', () {
      expect(VoiceMuscleGroupGrammar.resolve('foo'), isNull);
      expect(VoiceMuscleGroupGrammar.resolve(''), isNull);
      expect(VoiceMuscleGroupGrammar.resolve('cardio'), isNull);
    });

    test('is case-insensitive', () {
      expect(VoiceMuscleGroupGrammar.resolve('CHEST'), MuscleStimulus.midChest);
      expect(VoiceMuscleGroupGrammar.resolve('Lats'), MuscleStimulus.lats);
    });

    test('trims whitespace', () {
      expect(
        VoiceMuscleGroupGrammar.resolve(' chest '),
        MuscleStimulus.midChest,
      );
    });

    test('all resolved values are valid MuscleStimulus group strings', () {
      const knownAliases = [
        'chest',
        'back',
        'shoulders',
        'biceps',
        'triceps',
        'legs',
        'abs',
      ];
      for (final alias in knownAliases) {
        final resolved = VoiceMuscleGroupGrammar.resolve(alias);
        expect(
          MuscleStimulus.isValidMuscleGroup(resolved ?? ''),
          isTrue,
          reason:
              '"$alias" → "$resolved" must be a valid MuscleStimulus group string',
        );
      }
    });
  });
}
