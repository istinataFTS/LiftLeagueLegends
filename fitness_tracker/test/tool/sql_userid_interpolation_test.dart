import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/shared.dart';
import '../../tool/convention_rules/sql_userid_interpolation.dart';

void main() {
  final rule = SqlUseridInterpolationRule();

  group('SqlUseridInterpolationRule', () {
    test('passes when whereOwned helper is used (no interpolation)', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            "final result = await db.query(\n"
            "  tableName,\n"
            "  where: whereOwned(ownerId: ownerId).where,\n"
            "  whereArgs: whereOwned(ownerId: ownerId).whereArgs,\n"
            ");\n",
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes when parameterised whereArgs are used without interpolation', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            "final result = await db.query(\n"
            "  tableName,\n"
            "  where: 'owner_user_id = ?',\n"
            "  whereArgs: [ownerId],\n"
            ");\n",
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('reports a violation for userId interpolated in where: string', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            "final result = await db.query(tableName, where: 'owner = \$userId');\n",
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'sql-userid-interpolation');
      expect(violations.first.line, 1);
    });

    test('reports a violation for ownerId interpolated in rawQuery', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            "final rows = await db.rawQuery('SELECT * FROM t WHERE id = \$ownerId');\n",
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'sql-userid-interpolation');
    });

    test('reports a violation for currentUserId in rawUpdate', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            'await db.rawUpdate("UPDATE t SET x=1 WHERE uid=\$currentUserId");\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    test('does not report non-SQL interpolation of userId', () async {
      // userId in a log statement is fine
      final repo = FakeRepoView({
        'lib/data/datasources/local/foo_datasource.dart':
            "AppLogger.debug('syncing for \$userId');\n"
            "final msg = 'owner: \$ownerId';\n",
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });
  });
}
