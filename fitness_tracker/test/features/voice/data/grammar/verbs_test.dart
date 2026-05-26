import 'package:fitness_tracker/features/voice/data/grammar/verbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceVerbGrammar.logVerbs', () {
    test('contains core log verbs', () {
      for (final v in [
        'log',
        'add',
        'record',
        'track',
        'did',
        'done',
        'save',
      ]) {
        expect(
          VoiceVerbGrammar.logVerbs.contains(v),
          isTrue,
          reason: '"$v" must be in logVerbs',
        );
      }
    });

    test('contains inflected forms', () {
      expect(VoiceVerbGrammar.logVerbs.contains('logged'), isTrue);
      expect(VoiceVerbGrammar.logVerbs.contains('added'), isTrue);
      expect(VoiceVerbGrammar.logVerbs.contains('recorded'), isTrue);
    });
  });

  group('VoiceVerbGrammar.editVerbs', () {
    test('contains core edit verbs', () {
      for (final v in [
        'edit',
        'update',
        'change',
        'fix',
        'correct',
        'adjust',
      ]) {
        expect(
          VoiceVerbGrammar.editVerbs.contains(v),
          isTrue,
          reason: '"$v" must be in editVerbs',
        );
      }
    });

    test('contains inflected forms', () {
      expect(VoiceVerbGrammar.editVerbs.contains('updated'), isTrue);
      expect(VoiceVerbGrammar.editVerbs.contains('changed'), isTrue);
    });
  });

  group('VoiceVerbGrammar.deleteVerbs', () {
    test('contains core delete verbs', () {
      for (final v in [
        'delete',
        'remove',
        'undo',
        'cancel',
        'scratch',
        'forget',
        'erase',
      ]) {
        expect(
          VoiceVerbGrammar.deleteVerbs.contains(v),
          isTrue,
          reason: '"$v" must be in deleteVerbs',
        );
      }
    });

    test('contains inflected forms', () {
      expect(VoiceVerbGrammar.deleteVerbs.contains('deleted'), isTrue);
      expect(VoiceVerbGrammar.deleteVerbs.contains('removed'), isTrue);
    });
  });

  group('VoiceVerbGrammar.queryWords', () {
    test('contains core query words', () {
      for (final v in [
        'what',
        'how',
        'show',
        'tell',
        'get',
        'check',
        'display',
      ]) {
        expect(
          VoiceVerbGrammar.queryWords.contains(v),
          isTrue,
          reason: '"$v" must be in queryWords',
        );
      }
    });

    test("contains what's contraction", () {
      expect(VoiceVerbGrammar.queryWords.contains("what's"), isTrue);
      expect(VoiceVerbGrammar.queryWords.contains('whats'), isTrue);
    });
  });

  group('mutual exclusivity', () {
    test('no overlap between logVerbs and deleteVerbs', () {
      final overlap = VoiceVerbGrammar.logVerbs.intersection(
        VoiceVerbGrammar.deleteVerbs,
      );
      expect(overlap, isEmpty, reason: 'log and delete verbs must not overlap');
    });

    test('no overlap between editVerbs and deleteVerbs', () {
      final overlap = VoiceVerbGrammar.editVerbs.intersection(
        VoiceVerbGrammar.deleteVerbs,
      );
      expect(
        overlap,
        isEmpty,
        reason: 'edit and delete verbs must not overlap',
      );
    });
  });
}
