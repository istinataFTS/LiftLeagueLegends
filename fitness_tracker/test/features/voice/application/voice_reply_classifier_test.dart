import 'package:fitness_tracker/features/voice/application/voice_reply_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceReplyClassifier.classify', () {
    // -------------------------------------------------------------------------
    // Confirm phrases
    // -------------------------------------------------------------------------

    group('confirm phrases → VoiceReplyKind.confirm', () {
      const confirms = <String>[
        'yes',
        'yeah',
        'yep',
        'yup',
        'yes please',
        'do it',
        'go ahead',
        'confirm',
        'confirmed',
        'sounds good',
        'log it',
        'save it',
      ];

      for (final phrase in confirms) {
        test('"$phrase"', () {
          expect(VoiceReplyClassifier.classify(phrase), VoiceReplyKind.confirm);
        });
      }

      test('mixed case "YES"', () {
        expect(VoiceReplyClassifier.classify('YES'), VoiceReplyKind.confirm);
      });

      test('mixed case "Go Ahead"', () {
        expect(
          VoiceReplyClassifier.classify('Go Ahead'),
          VoiceReplyKind.confirm,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Cancel phrases
    // -------------------------------------------------------------------------

    group('cancel phrases → VoiceReplyKind.cancel', () {
      const cancels = <String>[
        'cancel',
        'nevermind',
        'never mind',
        'no',
        'stop',
      ];

      for (final phrase in cancels) {
        test('"$phrase"', () {
          expect(VoiceReplyClassifier.classify(phrase), VoiceReplyKind.cancel);
        });
      }

      test('mixed case "CANCEL"', () {
        expect(VoiceReplyClassifier.classify('CANCEL'), VoiceReplyKind.cancel);
      });

      test('mixed case "No"', () {
        expect(VoiceReplyClassifier.classify('No'), VoiceReplyKind.cancel);
      });
    });

    // -------------------------------------------------------------------------
    // Correction — extra data or non-anchor match must NOT confirm or cancel
    // -------------------------------------------------------------------------

    group('correction phrases → VoiceReplyKind.correction', () {
      test('"yes but make it 8 reps" — extra data after affirmation', () {
        expect(
          VoiceReplyClassifier.classify('yes but make it 8 reps'),
          VoiceReplyKind.correction,
        );
      });

      test(
        '"yes please make it 80 kg" — affirmation with trailing content',
        () {
          expect(
            VoiceReplyClassifier.classify('yes please make it 80 kg'),
            VoiceReplyKind.correction,
          );
        },
      );

      test('"cancel my membership" — cancel word not anchored to end', () {
        expect(
          VoiceReplyClassifier.classify('cancel my membership'),
          VoiceReplyKind.correction,
        );
      });

      test('"no thanks" — cancel word not anchored to end', () {
        expect(
          VoiceReplyClassifier.classify('no thanks'),
          VoiceReplyKind.correction,
        );
      });

      test('"actually make it 10 reps" — edit instruction', () {
        expect(
          VoiceReplyClassifier.classify('actually make it 10 reps'),
          VoiceReplyKind.correction,
        );
      });

      test('"change the weight to 90" — field correction', () {
        expect(
          VoiceReplyClassifier.classify('change the weight to 90'),
          VoiceReplyKind.correction,
        );
      });

      test('"no wait make it 8" — cancel word with extra content', () {
        expect(
          VoiceReplyClassifier.classify('no wait make it 8'),
          VoiceReplyKind.correction,
        );
      });

      test('empty string — neither confirm nor cancel', () {
        expect(VoiceReplyClassifier.classify(''), VoiceReplyKind.correction);
      });
    });

    // -------------------------------------------------------------------------
    // Anchoring: confirm/cancel words must match whole transcript
    // -------------------------------------------------------------------------

    group('anchoring — confirm word inside longer phrase is correction', () {
      test('"please confirm the weight"', () {
        expect(
          VoiceReplyClassifier.classify('please confirm the weight'),
          VoiceReplyKind.correction,
        );
      });

      test('"do it again"', () {
        expect(
          VoiceReplyClassifier.classify('do it again'),
          VoiceReplyKind.correction,
        );
      });

      test('"stop the timer"', () {
        expect(
          VoiceReplyClassifier.classify('stop the timer'),
          VoiceReplyKind.correction,
        );
      });

      test('"yeah right" — affirmation with trailing word', () {
        expect(
          VoiceReplyClassifier.classify('yeah right'),
          VoiceReplyKind.correction,
        );
      });
    });
  });
}
