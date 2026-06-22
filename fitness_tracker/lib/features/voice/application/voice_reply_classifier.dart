/// Classification of a transcript captured while a mutation confirmation is
/// pending (redesign-overview.md §5).
enum VoiceReplyKind { confirm, cancel, correction }

/// Classifies a final STT transcript captured while a mutation confirmation is
/// pending. Pure and dependency-free so the security-sensitive decision is
/// unit-testable in isolation (redesign-overview.md §5). Mirrors Plan 1 WI-2's
/// `shouldTranscribe()` static-helper pattern.
abstract final class VoiceReplyClassifier {
  VoiceReplyClassifier._();

  /// All Unicode punctuation. Stripped (not space-replaced) before matching so
  /// both Whisper edge artefacts ("Confirm.") AND internal punctuation
  /// ("yes, do it", "let's go") normalise to the bare phrase. Removing rather
  /// than space-replacing keeps contractions intact ("let's" → "lets",
  /// "that's" → "thats").
  static final RegExp _punct = RegExp(r'\p{P}', unicode: true);

  /// Collapses any run of whitespace to a single space so a stripped comma
  /// ("yes, do it" → "yes  do it") does not leave a double space that would
  /// break the anchored match.
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Pure affirmations — anchored ^…$ so anything carrying extra data
  /// ("yes but make it 8") falls through to [VoiceReplyKind.correction].
  /// H2: deliberately NOT the server's `\b`-based AFFIRMATION_REGEX.
  /// Phrases are stored in normalised (apostrophe-free, lowercase) form to
  /// match [_normalize]'s output.
  static final RegExp _confirm = RegExp(
    r'^(yes|yeah|yep|yup|yes please|yes do it|yep do it|do it|lets do it|'
    r'go ahead|go for it|lets go|confirm|confirmed|i confirm|please confirm|'
    r'yes confirm|sounds good|looks good|log it|save it|okay|ok|correct|'
    r'thats right|thats correct|sure|absolutely|definitely|for sure|perfect)$',
    caseSensitive: false,
  );

  /// Pure cancels — anchored so "cancel my membership" does NOT cancel.
  /// Lifted verbatim from the former `_verbalCancelPattern` plus done-words.
  static final RegExp _cancel = RegExp(
    r'^(cancel|nevermind|never mind|no|stop|no thanks|no thank you|nope|'
    r'forget it|forget that)$',
    caseSensitive: false,
  );

  /// Classifies [transcript] as a pure affirmation, a pure cancellation, or
  /// a correction that should be forwarded to the LLM. Normalises the input
  /// (lowercase, strip ALL punctuation, collapse whitespace) so that Whisper
  /// artefacts (capitalisation, trailing period) and natural internal
  /// punctuation ("yes, do it") do not cause a miss.
  static VoiceReplyKind classify(String transcript) {
    final t = _normalize(transcript);
    if (_confirm.hasMatch(t)) return VoiceReplyKind.confirm;
    if (_cancel.hasMatch(t)) return VoiceReplyKind.cancel;
    return VoiceReplyKind.correction;
  }

  static String _normalize(String transcript) => transcript
      .toLowerCase()
      .replaceAll(_punct, '')
      .replaceAll(_whitespace, ' ')
      .trim();
}
