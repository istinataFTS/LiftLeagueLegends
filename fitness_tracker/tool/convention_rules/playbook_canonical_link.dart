import 'shared.dart';

/// Every file in `.claude/skills/` must:
///  1. Declare the six required header fields.
///  2. Have a valid ISO-8601 date in `Last verified:`.
///  3. Have every `[[name]]` canonical reference resolve to `.claude/reference/<name>.md`.
///  4. Have `Estimated steps:` match the count of `### N.` step headings.
///  5. Have every `KNOWN_ISSUES.md#<anchor>` link resolve to a real heading.
///  6. Have every backtick-wrapped concrete source-file path point to an existing file.
///  7. Include the four-command verification block.
///  8. Be anchored to at least one `[[canonical]]` or one KNOWN_ISSUES.md entry.
final class PlaybookCanonicalLinkRule implements ConventionRule {
  @override
  String get id => 'playbook-canonical-link';

  @override
  String get description =>
      '.claude/skills/ playbooks must declare valid metadata, resolve all '
      'canonical and KNOWN_ISSUES references, and contain the verification block.';

  static const _skillsDir = '.claude/skills';
  static const _referenceDir = '.claude/reference';
  static const _knownIssuesPath = 'KNOWN_ISSUES.md';

  static const _requiredHeaderFields = [
    'Task:',
    'When to use:',
    'Estimated steps:',
    'Last verified:',
    'Canonical references:',
    'Touches:',
  ];

  /// These four commands must appear verbatim in the Verification block.
  static const _verificationCommands = [
    'dart format --output=none --set-exit-if-changed',
    'flutter analyze',
    'dart run tool/check_conventions.dart',
    'flutter test',
  ];

  static final _wikiLinkPattern = RegExp(r'\[\[(\w[\w_-]*)\]\]');
  static final _knownIssuesAnchorPattern = RegExp(r'KNOWN_ISSUES\.md#([\w-]+)');

  /// Matches backtick-wrapped Dart file paths, optionally with a line suffix.
  /// Angle brackets in the path signal a template placeholder — those are skipped.
  static final _backtickDartPathPattern = RegExp(
    r'`((?:lib|test)/[^`<>]+\.dart)(?::\d+)?`',
  );

  static final _stepHeadingPattern = RegExp(r'^### \d+\.', multiLine: true);

  static final _estimatedStepsPattern = RegExp(r'Estimated steps:\*\*\s*(\d+)');

  static final _lastVerifiedValuePattern = RegExp(
    r'Last verified:\*\*\s*(\S+)',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listFiles(_skillsDir);
    final allMdFiles = files.where((f) => f.endsWith('.md')).toList()..sort();

    // Third-party skills installed via `npx skills add ...` ship under
    // `.claude/skills/<plugin-name>/` and bring their own `SKILL.md` plus
    // ancillary `.md` files (helpers, reference docs). Those aren't project
    // playbooks — they have their own structure and don't follow our schema.
    // Skip any directory that contains a `SKILL.md`.
    final thirdPartySkillDirs = allMdFiles
        .where((f) => f.split('/').last == 'SKILL.md')
        .map((f) => f.substring(0, f.lastIndexOf('/') + 1))
        .toSet();

    final mdFiles = allMdFiles
        .where(
          (f) =>
              !thirdPartySkillDirs.any((dir) => f.startsWith(dir)),
        )
        .toList();

    if (mdFiles.isEmpty) return [];

    final knownIssuesAnchors = await _loadKnownIssuesAnchors(repo);
    final referenceNames = await _loadReferenceNames(repo);

    final violations = <Violation>[];
    for (final path in mdFiles) {
      final content = await repo.readFile(path);
      if (content == null) continue;
      violations.addAll(
        await _checkPlaybook(
          path,
          content,
          knownIssuesAnchors,
          referenceNames,
          repo,
        ),
      );
    }
    return violations;
  }

  // ---------------------------------------------------------------------------
  // Pre-loaders
  // ---------------------------------------------------------------------------

  Future<Set<String>> _loadKnownIssuesAnchors(RepoView repo) async {
    final content = await repo.readFile(_knownIssuesPath);
    if (content == null) return {};
    return RegExp(
      r'^### (.+)',
      multiLine: true,
    ).allMatches(content).map((m) => _githubSlug(m.group(1)!.trim())).toSet();
  }

  Future<Set<String>> _loadReferenceNames(RepoView repo) async {
    final files = await repo.listFiles(_referenceDir);
    return files
        .where((f) => f.endsWith('.md'))
        .map((f) => f.split('/').last.replaceAll('.md', ''))
        .toSet();
  }

  /// Converts a heading to its GitHub Markdown anchor slug.
  String _githubSlug(String heading) => heading
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .trim();

  // ---------------------------------------------------------------------------
  // Per-playbook checks
  // ---------------------------------------------------------------------------

  Future<List<Violation>> _checkPlaybook(
    String path,
    String content,
    Set<String> knownIssuesAnchors,
    Set<String> referenceNames,
    RepoView repo,
  ) async {
    final violations = <Violation>[];

    void report(String message, String fixHint, {int? line}) {
      violations.add(
        Violation(
          ruleId: id,
          filePath: path,
          line: line,
          message: message,
          fixHint: fixHint,
        ),
      );
    }

    // --- Check 1: Required header fields present ---
    for (final field in _requiredHeaderFields) {
      if (!content.contains('**$field')) {
        report(
          'missing required header field "$field"',
          'Add "- **$field** <value>" to the metadata block at the top '
              'of the playbook.',
        );
      }
    }

    // --- Check 2: Last verified is a valid ISO-8601 date ---
    final lastVerifiedMatch = _lastVerifiedValuePattern.firstMatch(content);
    if (lastVerifiedMatch != null) {
      final dateStr = lastVerifiedMatch.group(1)!.trim();
      if (!isIsoDate(dateStr)) {
        report(
          '"Last verified" value "$dateStr" is not a valid ISO-8601 date',
          'Change the date to YYYY-MM-DD format.',
        );
      }
    }

    // --- Check 3: Estimated steps matches actual step count ---
    final estimatedMatch = _estimatedStepsPattern.firstMatch(content);
    if (estimatedMatch != null) {
      final declared = int.tryParse(estimatedMatch.group(1)!.trim()) ?? -1;
      final actual = _stepHeadingPattern.allMatches(content).length;
      if (declared != actual) {
        report(
          '"Estimated steps: $declared" does not match actual step '
              'count ($actual)',
          'Update "Estimated steps:" to $actual, or add/remove step headings.',
        );
      }
    }

    // --- Check 4: All [[name]] wiki-links resolve to a canonical reference ---
    // Deduplicate by name to avoid flooding violations for repeated links.
    final reportedWikiLinks = <String>{};
    for (final match in _wikiLinkPattern.allMatches(content)) {
      final name = match.group(1)!;
      if (!referenceNames.contains(name) && reportedWikiLinks.add(name)) {
        report(
          '[[$name]] does not resolve to .claude/reference/$name.md',
          'Add .claude/reference/$name.md or correct the [[$name]] link.',
          line: _lineOf(content, match.start),
        );
      }
    }

    // --- Check 5: KNOWN_ISSUES.md anchors resolve ---
    final reportedAnchors = <String>{};
    for (final match in _knownIssuesAnchorPattern.allMatches(content)) {
      final anchor = match.group(1)!;
      if (!knownIssuesAnchors.contains(anchor) && reportedAnchors.add(anchor)) {
        report(
          'KNOWN_ISSUES.md#$anchor does not match any heading in KNOWN_ISSUES.md',
          'Check the anchor spelling. Run: '
              'grep -nE \'^### \' KNOWN_ISSUES.md',
          line: _lineOf(content, match.start),
        );
      }
    }

    // --- Check 6: Backtick-wrapped concrete Dart file paths must exist ---
    final reportedPaths = <String>{};
    for (final match in _backtickDartPathPattern.allMatches(content)) {
      final rawPath = match.group(1)!;
      // Strip line-number suffix before existence check.
      final filePath = rawPath.split(':').first;
      if (!reportedPaths.add(filePath)) continue;
      final exists = await repo.readFile(filePath) != null;
      if (!exists) {
        report(
          'source-file reference `$rawPath` points to a non-existent file',
          'Update the path or remove the reference if the file was moved.',
          line: _lineOf(content, match.start),
        );
      }
    }

    // --- Check 7: Verification block must contain the four required commands ---
    for (final command in _verificationCommands) {
      if (!content.contains(command)) {
        report(
          'missing required verification command "$command"',
          'Add the full four-command verification block per the playbook schema.',
        );
      }
    }

    // --- Check 8: Must be anchored to at least one canonical or KNOWN_ISSUES entry ---
    final hasCanonical = _wikiLinkPattern.hasMatch(content);
    final hasKnownIssuesAnchor = _knownIssuesAnchorPattern.hasMatch(content);
    if (!hasCanonical && !hasKnownIssuesAnchor) {
      report(
        'playbook has no [[canonical]] references and no KNOWN_ISSUES.md anchors',
        'Add at least one [[name]] canonical reference or a KNOWN_ISSUES.md '
            'anchor in the Pitfalls section.',
      );
    }

    return violations;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the 1-based line number of [offset] within [content].
  int _lineOf(String content, int offset) =>
      '\n'.allMatches(content.substring(0, offset)).length + 1;
}
