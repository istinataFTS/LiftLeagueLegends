import 'shared.dart';

/// Every entry in `KNOWN_ISSUES.md` must have the nine mandatory fields with
/// valid controlled-vocabulary values and ISO-8601 dates.
///
/// Mandatory fields: Severity, Status, First observed, Last verified, Area,
/// Symptom (header), Root cause (header), Workaround / fix (header),
/// References (header).
///
/// This rule was deferred from Adoption 01 (where the file was created) and
/// bundled into Adoption 04 per the master plan.
final class KnownIssuesSchemaRule implements ConventionRule {
  @override
  String get id => 'known-issues-schema';

  @override
  String get description =>
      'KNOWN_ISSUES.md entries must have all nine mandatory fields with valid values.';

  static const _filePath = 'KNOWN_ISSUES.md';

  static const _validSeverities = {'Critical', 'High', 'Medium', 'Low'};
  static const _validStatuses = {'Active', 'Mitigated', 'Resolved-but-monitor'};
  static const _validAreas = {
    'sync',
    'voice',
    'db',
    'di',
    'ci',
    'platform',
    'other',
  };

  // Applied to the full entry block (multiLine so ^ matches per line,
  // and \S+ stops at the first whitespace after the value).
  static final _severityPattern = RegExp(
    r'^\s*-\s*\*\*Severity:\*\*\s*(\S+)',
    multiLine: true,
  );
  static final _statusPattern = RegExp(
    r'^\s*-\s*\*\*Status:\*\*\s*(\S+)',
    multiLine: true,
  );
  static final _firstObservedPattern = RegExp(
    r'^\s*-\s*\*\*First observed:\*\*\s*(\S+)',
    multiLine: true,
  );
  static final _lastVerifiedPattern = RegExp(
    r'^\s*-\s*\*\*Last verified:\*\*\s*(\S+)',
    multiLine: true,
  );
  static final _areaPattern = RegExp(
    r'^\s*-\s*\*\*Area:\*\*\s*(\S+)',
    multiLine: true,
  );

  // isIsoDate is defined in shared.dart.

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final raw = await repo.readFile(_filePath);
    if (raw == null) {
      return [
        Violation(
          ruleId: id,
          filePath: _filePath,
          message: 'KNOWN_ISSUES.md not found.',
          fixHint: 'Ensure KNOWN_ISSUES.md exists at the repo root.',
        ),
      ];
    }

    final violations = <Violation>[];
    final entries = _parseEntries(raw);

    for (final entry in entries) {
      violations.addAll(_validateEntry(entry));
    }

    return violations;
  }

  /// Splits the file into real entry blocks.
  ///
  /// Strategy:
  /// 1. Strip content inside triple-backtick code fences (the template lives there).
  /// 2. Split by `### ` headings.
  /// 3. Keep only blocks that contain `- **` field bullets — this excludes
  ///    ToC category headers (`### Sync`, `### Voice`, etc.) which have only
  ///    numbered list items.
  List<_Entry> _parseEntries(String raw) {
    // Remove code-fence blocks so the template doesn't get parsed as an entry.
    final stripped = raw.replaceAll(
      RegExp(r'```[\s\S]*?```', dotAll: true),
      '',
    );

    final entries = <_Entry>[];
    final sections = stripped.split(RegExp(r'(?=^### )', multiLine: true));

    for (final section in sections) {
      if (!section.startsWith('### ')) continue;

      // Skip ToC category headers (### Sync, ### Voice, etc.) — they have
      // numbered list entries but no `- **Field:**` bullets.
      if (!section.contains('- **')) continue;

      final titleEnd = section.indexOf('\n');
      final title = titleEnd > 0
          ? section.substring(4, titleEnd).trim()
          : section.substring(4).trim();

      entries.add(_Entry(slug: title, content: section));
    }

    return entries;
  }

  List<Violation> _validateEntry(_Entry entry) {
    final violations = <Violation>[];
    final content = entry.content;

    // Extract field values using multiLine patterns applied to the full
    // entry block — avoids any CRLF / line-splitting edge cases.
    final severity = _severityPattern.firstMatch(content)?.group(1)?.trim();
    final status = _statusPattern.firstMatch(content)?.group(1)?.trim();
    final firstObserved = _firstObservedPattern
        .firstMatch(content)
        ?.group(1)
        ?.trim();
    final lastVerified = _lastVerifiedPattern
        .firstMatch(content)
        ?.group(1)
        ?.trim();
    final area = _areaPattern.firstMatch(content)?.group(1)?.trim();

    final hasSymptomHeader = content.contains('**Symptom**');
    final hasRootCauseHeader = content.contains('**Root cause**');
    final hasWorkaroundHeader = content.contains('**Workaround / fix**');
    final hasReferencesHeader = content.contains('**References**');

    void report(String msg) => violations.add(
      Violation(
        ruleId: id,
        filePath: _filePath,
        message: '"${entry.slug}" — $msg',
        fixHint:
            'Add or correct the field. See the template at the top of '
            'KNOWN_ISSUES.md for the required format.',
      ),
    );

    if (severity == null) {
      report('missing field "Severity"');
    } else if (!_validSeverities.contains(severity)) {
      report(
        'invalid Severity "$severity" — must be Critical, High, Medium, or Low',
      );
    }

    if (status == null) {
      report('missing field "Status"');
    } else if (!_validStatuses.contains(status)) {
      report(
        'invalid Status "$status" — must be Active, Mitigated, or '
        'Resolved-but-monitor',
      );
    }

    if (firstObserved == null) {
      report('missing field "First observed"');
    } else if (!isIsoDate(firstObserved)) {
      report(
        'invalid "First observed" date "$firstObserved" — must be YYYY-MM-DD',
      );
    }

    if (lastVerified == null) {
      report('missing field "Last verified"');
    } else if (!isIsoDate(lastVerified)) {
      report(
        'invalid "Last verified" date "$lastVerified" — must be YYYY-MM-DD',
      );
    }

    if (area == null) {
      report('missing field "Area"');
    } else if (!_validAreas.contains(area)) {
      report(
        'invalid Area "$area" — must be one of: sync, voice, db, di, ci, '
        'platform, other',
      );
    }

    if (!hasSymptomHeader) report('missing section header "**Symptom**"');
    if (!hasRootCauseHeader) report('missing section header "**Root cause**"');
    if (!hasWorkaroundHeader) {
      report('missing section header "**Workaround / fix**"');
    }
    if (!hasReferencesHeader) report('missing section header "**References**"');

    return violations;
  }
}

final class _Entry {
  const _Entry({required this.slug, required this.content});

  final String slug;
  final String content;
}
