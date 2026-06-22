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
        // widened in fix/voice-confirm-classifier-normalize
        'i confirm',
        'please confirm',
        'yes confirm',
        'okay',
        'ok',
        'correct',
        "that's right",
        'thats right',
        'sure',
        // widened in fix/voice-confirm-phrases — free-form affirmations
        'go for it',
        "let's go",
        'lets go',
        'lets do it',
        'yes do it',
        'yep do it',
        'absolutely',
        'definitely',
        'for sure',
        'looks good',
        'thats correct',
        'perfect',
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
        // widened in fix/voice-confirm-classifier-normalize
        'no thanks',
        'nope',
        'forget it',
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

      test('"log bench press 80 kg" — workout log instruction', () {
        expect(
          VoiceReplyClassifier.classify('log bench press 80 kg'),
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

      // New phrases: anchoring must still hold
      test('"sure but make it 10" — new confirm word with extra data', () {
        expect(
          VoiceReplyClassifier.classify('sure but make it 10'),
          VoiceReplyKind.correction,
        );
      });

      test('"okay fine whatever" — new confirm word not anchored to end', () {
        expect(
          VoiceReplyClassifier.classify('okay fine whatever'),
          VoiceReplyKind.correction,
        );
      });

      test('"forget it all" — new cancel word not anchored to end', () {
        expect(
          VoiceReplyClassifier.classify('forget it all'),
          VoiceReplyKind.correction,
        );
      });

      test('"go for it now" — free-form confirm not anchored to end', () {
        expect(
          VoiceReplyClassifier.classify('go for it now'),
          VoiceReplyKind.correction,
        );
      });

      test('"absolutely not" — refusal must NOT confirm', () {
        // Anchored, so "absolutely not" != "absolutely" and falls through to
        // correction (forwarded to the LLM) rather than confirming.
        expect(
          VoiceReplyClassifier.classify('absolutely not'),
          VoiceReplyKind.correction,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Internal punctuation — natural commas / contractions must not break the
    // anchored match (the bug this fix closes).
    // -------------------------------------------------------------------------

    group('internal punctuation normalisation', () {
      test('"yes, do it" — internal comma still confirms', () {
        expect(
          VoiceReplyClassifier.classify('yes, do it'),
          VoiceReplyKind.confirm,
        );
      });

      test('"Go for it!" — capital + internal + trailing punct → confirm', () {
        expect(
          VoiceReplyClassifier.classify('Go for it!'),
          VoiceReplyKind.confirm,
        );
      });

      test('"Let\'s go." — contraction apostrophe → confirm', () {
        expect(
          VoiceReplyClassifier.classify("Let's go."),
          VoiceReplyKind.confirm,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Whisper punctuation normalisation — STT capitalisation + trailing period
    // These are the exact forms Whisper returns (device logcat verified).
    // -------------------------------------------------------------------------

    group(
      'Whisper normalisation — capitalisation and trailing punctuation',
      () {
        test('"Confirm." — capital + trailing period → confirm', () {
          expect(
            VoiceReplyClassifier.classify('Confirm.'),
            VoiceReplyKind.confirm,
          );
        });

        test('"I confirm." — filler prefix + trailing period → confirm', () {
          expect(
            VoiceReplyClassifier.classify('I confirm.'),
            VoiceReplyKind.confirm,
          );
        });

        test('"Yes." — capital + trailing period → confirm', () {
          expect(VoiceReplyClassifier.classify('Yes.'), VoiceReplyKind.confirm);
        });

        test('"confirm!" — trailing exclamation → confirm', () {
          expect(
            VoiceReplyClassifier.classify('confirm!'),
            VoiceReplyKind.confirm,
          );
        });

        test('"Okay." — capital + trailing period → confirm', () {
          expect(
            VoiceReplyClassifier.classify('Okay.'),
            VoiceReplyKind.confirm,
          );
        });

        test('"Cancel." — capital + trailing period → cancel', () {
          expect(
            VoiceReplyClassifier.classify('Cancel.'),
            VoiceReplyKind.cancel,
          );
        });

        test('"No thanks." — capital + trailing period → cancel', () {
          expect(
            VoiceReplyClassifier.classify('No thanks.'),
            VoiceReplyKind.cancel,
          );
        });

        test(
          '"yes but make it 8" — normalisation does not drop middle content',
          () {
            expect(
              VoiceReplyClassifier.classify('yes but make it 8'),
              VoiceReplyKind.correction,
            );
          },
        );
      },
    );
  });
}
