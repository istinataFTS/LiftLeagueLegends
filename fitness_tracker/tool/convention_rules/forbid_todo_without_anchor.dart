import 'shared.dart';

/// `// TODO` / `// FIXME` / `// XXX` / `// HACK` comments under `lib/` and
/// `test/` must reference a tracked anchor — a `KNOWN_ISSUES.md` slug
/// (`#kebab-case`), a GitHub issue or PR number (`#123`), or both
/// (`KNOWN_ISSUES#slug`). Untracked TODOs decay into noise and silently
/// outlive the context that motivated them.
///
/// Accepted forms (any of these on the same line as the marker):
///
/// - `// TODO(#guest-catalog-pk-collision)` — KNOWN_ISSUES anchor
/// - `// TODO(#123)` — GitHub issue or PR
/// - `// FIXME: see KNOWN_ISSUES#some-anchor for context`
/// - `// XXX: drop after PR #99 merges`
///
/// Rejected:
///
/// - `// TODO` (bare)
/// - `// TODO refactor this later`
/// - `// FIXME flaky on Android`
///
/// `test/tool/` is exempt — convention-rule tests reference these patterns
/// in fixture strings, same rationale as the `no-skipped-tests` exemption.
///
/// Waiver:
///
/// ```dart
/// // convention-checker:allow=forbid-todo-without-anchor reason=<why, 10+>
/// ```
final class ForbidTodoWithoutAnchorRule implements ConventionRule {
  @override
  String get id => 'forbid-todo-without-anchor';

  @override
  String get description =>
      'TODO/FIXME/XXX/HACK comments must reference a tracked anchor '
      '(#kebab-anchor or #NNN issue/PR).';

  static const List<String> _scanRoots = ['lib', 'test'];
  static const String _exemptPrefix = 'test/tool/';

  /// Marker token at the start of a comment (case-insensitive).
  static final RegExp _marker = RegExp(
    r'//\s*(TODO|FIXME|XXX|HACK)\b',
    caseSensitive: false,
  );

  /// At least one of: `#kebab-anchor` (slug, lowercase + hyphens, len >= 3)
  /// or `#NNN` (an issue/PR number).
  static final RegExp _anchorRef = RegExp(r'#(?:[a-z][a-z0-9-]{2,}|\d+)\b');

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final violations = <Violation>[];

    for (final root in _scanRoots) {
      final files = await repo.listDartFiles(root);
      for (final path in files) {
        if (path.startsWith(_exemptPrefix)) continue;

        final content = await repo.readFile(path);
        if (content == null) continue;

        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final marker = _marker.firstMatch(line);
          if (marker == null) continue;
          if (_anchorRef.hasMatch(line)) continue;
          if (hasWaiver(lines, i, id)) continue;

          violations.add(
            Violation(
              ruleId: id,
              filePath: path,
              line: i + 1,
              message:
                  '${marker.group(1)!.toUpperCase()} comment without a tracker '
                  'anchor. Reference a KNOWN_ISSUES.md anchor (#kebab-slug) '
                  'or an issue/PR number (#NNN) on the same line.',
              fixHint:
                  'Either: (a) attach a tracker — '
                  '`// TODO(#some-anchor)` or `// TODO: see #123`, or '
                  '(b) resolve the TODO and delete the comment, or '
                  '(c) waive with '
                  '`// convention-checker:allow=forbid-todo-without-anchor '
                  'reason=<why>`.',
            ),
          );
        }
      }
    }

    return violations;
  }
}
