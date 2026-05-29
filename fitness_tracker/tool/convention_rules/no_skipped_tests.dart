import 'shared.dart';

/// Test files under `test/` must not skip tests in committed code.
///
/// Flags:
/// - `@Skip('reason')` — file/class-level skip annotation.
/// - `skip: true` / `skip: 'reason'` / `skip: kReason` — `test`, `testWidgets`,
///   or `group` parameter that disables a test.
/// - `solo: true` — third-party "run-only-this" parameter used by some
///   harnesses; treated as effectively skipping every other test.
///
/// `skip: false` and `skip: null` are accepted — they are the idiomatic way
/// to *explicitly* assert a test is not skipped.
///
/// **Exempt directory:** `test/tool/` is excluded. Those files test the
/// convention rules themselves and routinely reference the patterns this
/// rule detects (both in fixture heredocs and in test descriptions like
/// `test('flags @Skip annotation', ...)`); flagging them would produce
/// permanent self-violations with no actionable fix.
///
/// To opt out for a genuine temporary skip (e.g. waiting on an in-flight fix
/// linked to a tracked issue), add an inline waiver:
///
/// ```dart
/// // convention-checker:allow=no-skipped-tests reason=<why, 10+ chars>
/// ```
final class NoSkippedTestsRule implements ConventionRule {
  @override
  String get id => 'no-skipped-tests';

  @override
  String get description =>
      'Test files must not skip tests. Remove @Skip and skip:/solo: '
      'parameters before merging.';

  static const String _testRoot = 'test';

  /// Files at or below this prefix are exempt — they are convention-rule
  /// tests that legitimately mention skip patterns in fixtures and
  /// descriptions. See class doc.
  static const String _exemptPrefix = 'test/tool/';

  static final RegExp _skipAnnotation = RegExp(r'@Skip\b');

  // `skip: <truthy>` — anything other than `false` / `null` after the colon.
  static final RegExp _skipParam = RegExp(
    r'\bskip\s*:\s*(?!false\b|null\b)\S+',
  );

  // `solo: <truthy>` — same shape; not part of flutter_test but used by some
  // third-party harnesses to focus a single test.
  static final RegExp _soloParam = RegExp(
    r'\bsolo\s*:\s*(?!false\b|null\b)\S+',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles(_testRoot);
    final violations = <Violation>[];

    for (final path in files) {
      if (path.startsWith(_exemptPrefix)) continue;

      final content = await repo.readFile(path);
      if (content == null) continue;
      // Mask out triple-quoted string contents so test fixtures that embed
      // example skip patterns (e.g. in shared test helpers) don't trigger
      // false positives. Line numbers are preserved by retaining newlines.
      final lines = _maskTripleQuotedStrings(content).split('\n');

      for (var i = 0; i < lines.length; i++) {
        final code = _stripLineComment(lines[i]);
        if (code.isEmpty) continue;

        String? label;
        if (_skipAnnotation.hasMatch(code)) {
          label = '@Skip annotation';
        } else if (_skipParam.hasMatch(code)) {
          label = 'skip: parameter with a non-false/null value';
        } else if (_soloParam.hasMatch(code)) {
          label = 'solo: parameter with a non-false/null value';
        }
        if (label == null) continue;

        if (hasWaiver(lines, i, id)) continue;

        violations.add(
          Violation(
            ruleId: id,
            filePath: path,
            line: i + 1,
            message:
                '$label found — tests must not be skipped in committed code.',
            fixHint:
                'Delete the skip and either fix or remove the test. If the '
                'skip is genuinely temporary (waiting on a tracked fix), add '
                'an inline waiver: '
                '`// convention-checker:allow=no-skipped-tests reason=<why>` '
                'and reference the issue or KNOWN_ISSUES anchor.',
          ),
        );
      }
    }
    return violations;
  }

  /// Replaces the inner content of every `'''…'''` and `"""…"""` block with
  /// whitespace, preserving newlines so subsequent line numbers stay correct.
  /// Test fixtures often embed example skip/Skip patterns inside such blocks
  /// — masking prevents false positives without losing line accuracy.
  String _maskTripleQuotedStrings(String content) {
    String mask(String input, String quote) {
      final pattern = RegExp('$quote([\\s\\S]*?)$quote');
      return input.replaceAllMapped(pattern, (match) {
        final inner = match.group(1) ?? '';
        final masked = inner.replaceAll(RegExp(r'[^\n]'), ' ');
        return '$quote$masked$quote';
      });
    }

    var out = mask(content, "'''");
    out = mask(out, '"""');
    return out;
  }

  /// Removes a trailing `// …` comment from [line] so we don't match within
  /// it. Heuristic: leave the line untouched if the `//` falls inside an
  /// unterminated string literal — a perfect parser is overkill here and a
  /// rare false negative is preferable to a rare false positive on real code.
  String _stripLineComment(String line) {
    final idx = line.indexOf('//');
    if (idx < 0) return line;
    final before = line.substring(0, idx);
    final singleQuotes = "'".allMatches(before).length;
    final doubleQuotes = '"'.allMatches(before).length;
    if (singleQuotes.isOdd || doubleQuotes.isOdd) return line;
    return before;
  }
}
