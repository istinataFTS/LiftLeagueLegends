import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/migration_test_coverage.dart';
import '../../tool/convention_rules/shared.dart';

const _sourcePath = 'lib/data/datasources/local/database_helper.dart';

String _testPath(int v) =>
    'test/data/datasources/local/database_helper_v${v}_migration_test.dart';

/// Synthesises a minimal source body that contains `if (oldVersion < N)`
/// branches for each value in [versions].
String _sourceWithBranches(Iterable<int> versions) {
  final buf = StringBuffer('void _onUpgrade(int oldVersion) {\n');
  for (final v in versions) {
    buf.writeln('  if (oldVersion < $v) {}');
  }
  buf.writeln('}');
  return buf.toString();
}

void main() {
  final rule = MigrationTestCoverageRule();

  group('MigrationTestCoverageRule', () {
    test('passes when every covered branch has a matching test file', () async {
      final repo = FakeRepoView({
        _sourcePath: _sourceWithBranches([21, 22]),
        _testPath(21): '// v21 test',
        _testPath(22): '// v22 test',
      });

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('ignores branches below the minimum enforced version', () async {
      // v3..v20 lack dedicated tests but are exempt by design — the rule is
      // forward-only from v21.
      final repo = FakeRepoView({
        _sourcePath: _sourceWithBranches([3, 8, 17, 20, 21]),
        _testPath(21): '// v21 test',
      });

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('reports each covered branch that lacks a test file', () async {
      final repo = FakeRepoView({
        _sourcePath: _sourceWithBranches([21, 22, 23]),
        _testPath(21): '// v21 test',
        // v22 and v23 tests intentionally missing.
      });

      final violations = await rule.check(repo);

      expect(violations, hasLength(2));
      expect(
        violations.map((v) => v.message),
        containsAll([
          contains('oldVersion < 22 branch'),
          contains('oldVersion < 23 branch'),
        ]),
      );
      for (final v in violations) {
        expect(v.ruleId, 'migration-test-coverage');
        expect(v.filePath, _sourcePath);
        expect(v.fixHint, contains('database_helper_v21_migration_test.dart'));
      }
    });

    test(
      'tolerates whitespace variants like "oldVersion  <  22" in the source',
      () async {
        final repo = FakeRepoView({
          _sourcePath: 'if (oldVersion  <  22) {}',
          _testPath(22): '// v22 test',
        });

        final violations = await rule.check(repo);

        expect(violations, isEmpty);
      },
    );

    test(
      'reports a single violation if the source file itself is absent',
      () async {
        final repo = FakeRepoView({});

        final violations = await rule.check(repo);

        expect(violations, hasLength(1));
        expect(violations.single.message, contains('Source file not found'));
      },
    );
  });
}
