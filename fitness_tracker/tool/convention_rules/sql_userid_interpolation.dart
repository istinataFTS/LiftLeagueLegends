import 'shared.dart';

/// SQL queries must never interpolate an owner-id variable directly into the
/// SQL string literal. Use parameterised `whereArgs` (or `whereOwned(...)`)
/// instead. String interpolation is both an SQL-injection footgun and a
/// leak vector if the id value is wrong.
final class SqlUseridInterpolationRule implements ConventionRule {
  @override
  String get id => 'sql-userid-interpolation';

  @override
  String get description =>
      'SQL queries must not interpolate owner-id values into the string literal.';

  /// Matches a sqflite `where:` string argument or a rawQuery/rawUpdate/
  /// rawDelete first argument that contains an interpolated owner-id variable.
  ///
  /// Owner-id variable names covered: userId, ownerId, ownerUserId,
  /// user_id, currentUserId, uid.
  ///
  /// The regex is written as a plain (non-raw) Dart string so that both
  /// single and double quote characters can appear in the character class
  /// without escaping conflicts.
  static final _pattern = RegExp(
    "(?:where:\\s*['\"]|raw(?:Query|Update|Delete)\\(\\s*['\"])"
    "[^'\"\\n]*"
    r'\$\{?(?:userId|ownerId|ownerUserId|user_id|currentUserId|uid)\}?',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib/data');
    final violations = <Violation>[];

    for (final path in files) {
      final content = await repo.readFile(path);
      if (content == null) continue;

      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!_pattern.hasMatch(lines[i])) continue;
        violations.add(
          Violation(
            ruleId: id,
            filePath: path,
            line: i + 1,
            message:
                'Owner-id variable is interpolated into a SQL string literal.',
            fixHint:
                'Use parameterised whereArgs or the whereOwned(...) helper '
                'from UserScopedLocalDatasource. See the canonical datasource '
                'example in .claude/reference/datasource.md.',
          ),
        );
      }
    }

    return violations;
  }
}
