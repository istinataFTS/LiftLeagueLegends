/// Classification of a transcript captured while a mutation confirmation is
/// pending (redesign-overview.md §5).
enum VoiceReplyKind { confirm, cancel, correction }

/// Classifies a final STT transcript captured while a mutation confirmation is
/// pending. Pure and dependency-free so the security-sensitive decision is
/// unit-testable in isolation (redesign-overview.md §5). Mirrors Plan 1 WI-2's
/// `shouldTranscribe()` static-helper pattern.
abstract final class VoiceReplyClassifier {
  VoiceReplyClassifier._();

  /// Strips leading/trailing Unicode whitespace and punctuation before
  /// matching so that Whisper's capitalisation and trailing period
  /// ("Confirm." / "I confirm.") do not cause a miss on the anchored regexes.
  static final RegExp _edgePunct = RegExp(
    r'^[\s\p{P}]+|[\s\p{P}]+$',
    unicode: true,
  );

  /// Pure affirmations — anchored ^…$ so anything carrying extra data
  /// ("yes but make it 8") falls through to [VoiceReplyKind.correction].
  /// H2: deliberately NOT the server's `\b`-based AFFIRMATION_REGEX.
  static final RegExp _confirm = RegExp(
    r'^(yes|yeah|yep|yup|yes please|do it|go ahead|confirm|confirmed|'
    r'sounds good|log it|save it|i confirm|please confirm|yes confirm|'
    "okay|ok|correct|that's right|thats right|sure)\$",
    caseSensitive: false,
  );

  /// Pure cancels — anchored so "cancel my membership" does NOT cancel.
  /// Lifted verbatim from the former `_verbalCancelPattern` plus done-words.
  static final RegExp _cancel = RegExp(
    r'^(cancel|nevermind|never mind|no|stop|no thanks|nope|forget it)$',
    caseSensitive: false,
  );

  /// Classifies [transcript] as a pure affirmation, a pure cancellation, or
  /// a correction that should be forwarded to the LLM. Normalises the input
  /// (lowercase, strip leading/trailing punctuation) so that Whisper
  /// artefacts such as capitalisation and a trailing period do not cause a
  /// miss.
  static VoiceReplyKind classify(String transcript) {
    final t = transcript.toLowerCase().trim().replaceAll(_edgePunct, '');
    if (_confirm.hasMatch(t)) return VoiceReplyKind.confirm;
    if (_cancel.hasMatch(t)) return VoiceReplyKind.cancel;
    return VoiceReplyKind.correction;
  }
}
