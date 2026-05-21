import 'shared.dart';

/// Every concrete local datasource whose rows are owned by a user must extend
/// [UserScopedLocalDatasource]. Abstract interface files (no concrete class
/// declaration) and the files on the exemption list below are skipped.
///
/// Update the exemption list here and in the doc comment on
/// `lib/data/datasources/local/user_scoped_local_datasource.dart` together —
/// they must stay in sync.
final class UserScopedDatasourceRule implements ConventionRule {
  @override
  String get id => 'user-scoped-datasource';

  @override
  String get description =>
      'Concrete local datasources must extend UserScopedLocalDatasource.';

  /// Files that are intentionally exempt from the user-scoping requirement.
  /// Documented in the base class doc comment.
  static const _exemptFiles = {
    'lib/data/datasources/local/app_metadata_local_datasource.dart',
    'lib/data/datasources/local/muscle_factor_local_datasource.dart',
    'lib/data/datasources/local/pending_sync_delete_local_datasource.dart',
    'lib/data/datasources/local/pending_sync_delete_local_datasource_impl.dart',
  };

  /// Infrastructure / base-class files that are neither impls nor exempt.
  static const _skipFiles = {
    'lib/data/datasources/local/user_scoped_local_datasource.dart',
    'lib/data/datasources/local/database_helper.dart',
  };

  static final _concreteClassPattern =
      RegExp(r'^\s*class\s+\w+', multiLine: true);
  static final _extendsBasePattern =
      RegExp(r'\bextends\s+UserScopedLocalDatasource\b');

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib/data/datasources/local');
    final violations = <Violation>[];

    for (final path in files) {
      if (_exemptFiles.contains(path) || _skipFiles.contains(path)) continue;

      final content = await repo.readFile(path);
      if (content == null) continue;

      // Already compliant — has at least one user-scoped class.
      if (_extendsBasePattern.hasMatch(content)) continue;

      // Pure abstract interface: all class declarations are abstract.
      // A file with only abstract classes is a domain interface — skip.
      final hasConcreteClass = _concreteClassPattern.hasMatch(content) &&
          _concreteClassPattern
              .allMatches(content)
              .any((m) => !_isAbstractMatch(content, m.start));
      if (!hasConcreteClass) continue;

      violations.add(
        Violation(
          ruleId: id,
          filePath: path,
          message:
              'Concrete datasource class does not extend UserScopedLocalDatasource.',
          fixHint:
              'Extend UserScopedLocalDatasource, or add the file to the '
              'exemption list in tool/convention_rules/user_scoped_datasource.dart '
              'with a one-line reason.',
        ),
      );
    }

    return violations;
  }

  /// Returns `true` if the class keyword at [charOffset] is preceded by
  /// `abstract` on the same line.
  bool _isAbstractMatch(String content, int charOffset) {
    final lineStart = content.lastIndexOf('\n', charOffset) + 1;
    final linePrefix = content.substring(lineStart, charOffset);
    return linePrefix.trimLeft().startsWith('abstract');
  }
}
