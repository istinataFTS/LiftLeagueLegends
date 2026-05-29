import 'shared.dart';

/// Production code under `lib/` must not call the top-level `print(...)`
/// function. Use [AppLogger] instead so the message participates in level
/// gating, categorisation, and (in the future) remote log shipping.
///
/// `debugPrint(...)`, `AppLogger.debug/info/warning/error(...)`, member
/// calls like `obj.print(...)`, and Dart's `dart:developer` `log(...)` are
/// all allowed — the rule only matches a `print(` token that is not part of
/// a member-access chain.
///
/// **Known limitation:** declaring a method literally named `print`
/// (e.g. `void print() {}`) is rare but would currently be flagged because
/// the rule does not parse declarations vs. calls. If you really need such
/// a method, waive the declaration line with the standard waiver comment.
///
/// Genuine exceptions (e.g. a one-off tool entry point) waive with:
///
/// ```dart
/// // convention-checker:allow=forbid-print reason=<why, 10+ chars>
/// ```
final class ForbidPrintRule implements ConventionRule {
  @override
  String get id => 'forbid-print';

  @override
  String get description =>
      'Production code under lib/ must not call top-level print(). '
      'Use AppLogger instead.';

  static const String _root = 'lib';

  /// Match `print(` where it's either at the start of a (possibly indented)
  /// line or preceded by a non-identifier character (so `obj.print(` and
  /// `something_print(` are not flagged — only the bare top-level function).
  static final RegExp _printCall = RegExp(r'(?:^|[^A-Za-z0-9_.])print\s*\(');

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles(_root);
    final violations = <Violation>[];

    for (final path in files) {
      final content = await repo.readFile(path);
      if (content == null) continue;

      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final code = _stripLineComment(lines[i]);
        if (!_printCall.hasMatch(code)) continue;
        if (hasWaiver(lines, i, id)) continue;

        violations.add(
          Violation(
            ruleId: id,
            filePath: path,
            line: i + 1,
            message:
                'Top-level print() call found — use AppLogger.debug/info/'
                'warning/error instead.',
            fixHint:
                'Replace with AppLogger.<level>(message, category: \'<area>\'). '
                'If a print is genuinely necessary (e.g. a one-off CLI '
                'tool), waive with '
                '`// convention-checker:allow=forbid-print reason=<why>`.',
          ),
        );
      }
    }
    return violations;
  }

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
