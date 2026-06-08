/// Classification of a transcript captured while a mutation confirmation is
/// pending (redesign-overview.md §5).
enum VoiceReplyKind { confirm, cancel, correction }

/// Classifies a final STT transcript captured while a mutation confirmation is
/// pending. Pure and dependency-free so the security-sensitive decision is
/// unit-testable in isolation (redesign-overview.md §5). Mirrors Plan 1 WI-2's
/// `shouldTranscribe()` static-helper pattern.
abstract final class VoiceReplyClassifier {
  VoiceReplyClassifier._();

  /// Pure affirmations — anchored ^…$ so anything carrying extra data
  /// ("yes but make it 8") falls through to [VoiceReplyKind.correction].
  /// H2: deliberately NOT the server's `\b`-based AFFIRMATION_REGEX.
  static final RegExp _confirm = RegExp(
    r'^(yes|yeah|yep|yup|yes please|do it|go ahead|confirm|confirmed|'
    r'sounds good|log it|save it)$',
    caseSensitive: false,
  );

  /// Pure cancels — anchored so "cancel my membership" does NOT cancel.
  /// Lifted verbatim from the former `_verbalCancelPattern` plus done-words.
  static final RegExp _cancel = RegExp(
    r'^(cancel|nevermind|never mind|no|stop)$',
    caseSensitive: false,
  );

  /// Classifies [transcript] (assumed already trimmed by the caller) as a
  /// pure affirmation, a pure cancellation, or a correction that should be
  /// forwarded to the LLM.
  static VoiceReplyKind classify(String transcript) {
    if (_confirm.hasMatch(transcript)) return VoiceReplyKind.confirm;
    if (_cancel.hasMatch(transcript)) return VoiceReplyKind.cancel;
    return VoiceReplyKind.correction;
  }
}
