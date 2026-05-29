import 'shared.dart';

/// Every `if (oldVersion < N)` branch in
/// `lib/data/datasources/local/database_helper.dart` (for
/// `N >= _minimumEnforcedVersion`) must have a corresponding migration test
/// file at `test/data/datasources/local/database_helper_vN_migration_test.dart`.
///
/// The dedicated-migration-test pattern was introduced with v21
/// (`database_helper_v21_migration_test.dart`) — older migrations
/// (v3–v20) shipped before the convention and are not backfilled. The
/// minimum enforced version is therefore set to 21; bumping the floor is a
/// deliberate decision that must be matched by ensuring every newly-covered
/// branch has a real test.
final class MigrationTestCoverageRule implements ConventionRule {
  @override
  String get id => 'migration-test-coverage';

  @override
  String get description =>
      'Every if (oldVersion < N) branch in DatabaseHelper._onUpgrade '
      '(for N >= $_minimumEnforcedVersion) must have a corresponding '
      'database_helper_vN_migration_test.dart file.';

  static const int _minimumEnforcedVersion = 21;
  static const String _sourcePath =
      'lib/data/datasources/local/database_helper.dart';
  static const String _testDir = 'test/data/datasources/local';

  static final RegExp _branchPattern = RegExp(r'oldVersion\s*<\s*(\d+)');

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final source = await repo.readFile(_sourcePath);
    if (source == null) {
      return [
        Violation(
          ruleId: id,
          filePath: _sourcePath,
          message: 'Source file not found.',
          fixHint:
              'Did you rename DatabaseHelper or move the file? Update '
              'MigrationTestCoverageRule._sourcePath.',
        ),
      ];
    }

    final versions = _branchPattern
        .allMatches(source)
        .map((m) => int.parse(m.group(1)!))
        .where((v) => v >= _minimumEnforcedVersion)
        .toSet();

    final sortedVersions = versions.toList()..sort();
    final violations = <Violation>[];

    for (final v in sortedVersions) {
      final expected = '$_testDir/database_helper_v${v}_migration_test.dart';
      if (await repo.readFile(expected) == null) {
        violations.add(
          Violation(
            ruleId: id,
            filePath: _sourcePath,
            message:
                'oldVersion < $v branch has no matching migration test at '
                '"$expected".',
            fixHint:
                'Create $expected following the pattern in '
                'database_helper_v21_migration_test.dart. Cover at least: '
                '(a) fresh-install no-op via createSchema, '
                '(b) upgrade from v${v - 1} with representative pre-state, '
                '(c) the no-op / idempotent case for the new migration.',
          ),
        );
      }
    }

    return violations;
  }
}
