import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/shared.dart';
import '../../tool/convention_rules/user_scoped_datasource.dart';

void main() {
  final rule = UserScopedDatasourceRule();

  group('UserScopedDatasourceRule', () {
    test(
      'passes when all concrete impls extend UserScopedLocalDatasource',
      () async {
        final repo = FakeRepoView({
          'lib/data/datasources/local/foo_local_datasource_impl.dart':
              'class FooLocalDataSourceImpl extends UserScopedLocalDatasource {\n}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test(
      'passes for pure abstract interface files (no concrete class)',
      () async {
        final repo = FakeRepoView({
          'lib/data/datasources/local/foo_local_datasource.dart':
              'abstract class FooLocalDataSource {\n'
              '  Future<void> doSomething();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test(
      'passes when file has both abstract interface and concrete impl that extends base',
      () async {
        final repo = FakeRepoView({
          'lib/data/datasources/local/exercise_local_datasource.dart':
              'abstract class ExerciseLocalDataSource {\n'
              '  Future<void> getAll();\n'
              '}\n'
              'class ExerciseLocalDataSourceImpl extends UserScopedLocalDatasource\n'
              '    implements ExerciseLocalDataSource {\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test('passes for the base class file itself', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/user_scoped_local_datasource.dart':
            'abstract class UserScopedLocalDatasource {\n}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes for database_helper.dart (infra skip)', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/database_helper.dart':
            'class DatabaseHelper {\n  Future<void> open() async {}\n}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes for files on the exemption list', () async {
      final repo = FakeRepoView({
        'lib/data/datasources/local/app_metadata_local_datasource.dart':
            'class AppMetadataLocalDataSource {\n  Future<void> get() async {}\n}\n',
        'lib/data/datasources/local/muscle_factor_local_datasource.dart':
            'class MuscleFactorLocalDataSource {\n  Future<void> get() async {}\n}\n',
        'lib/data/datasources/local/pending_sync_delete_local_datasource.dart':
            'abstract class PendingSyncDeleteLocalDataSource {\n}\n',
        'lib/data/datasources/local/pending_sync_delete_local_datasource_impl.dart':
            'class PendingSyncDeleteLocalDataSourceImpl {\n  Future<void> get() async {}\n}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'reports a violation for a concrete class that does not extend the base',
      () async {
        final repo = FakeRepoView({
          'lib/data/datasources/local/bar_local_datasource_impl.dart':
              'class BarLocalDataSourceImpl implements BarLocalDataSource {\n'
              '  Future<void> get() async {}\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'user-scoped-datasource');
        expect(
          violations.first.filePath,
          'lib/data/datasources/local/bar_local_datasource_impl.dart',
        );
      },
    );

    test(
      'fix hint mentions authenticated-owner-only with no guest mode',
      () async {
        final repo = FakeRepoView({
          'lib/data/datasources/local/baz_local_datasource_impl.dart':
              'class BazLocalDataSourceImpl {\n'
              '  Future<void> get() async {}\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.fixHint, contains('no guest mode'));
        expect(violations.first.fixHint, contains('authenticated-owner-only'));
      },
    );

    test('exemption list contains exactly the three documented non-user-scoped '
        'datasources — no guest-mode exemptions', () {
      // This test locks the exemption list so any new addition requires an
      // explicit review. The three exempt datasources (AppMetadata,
      // MuscleFactor, PendingSyncDelete) are not user-scoped by design and
      // have nothing to do with guest mode. Adding a guest-related exemption
      // here would be a regression.
      expect(UserScopedDatasourceRule.exemptFiles, hasLength(4));
      expect(
        UserScopedDatasourceRule.exemptFiles,
        containsAll([
          'lib/data/datasources/local/app_metadata_local_datasource.dart',
          'lib/data/datasources/local/muscle_factor_local_datasource.dart',
          'lib/data/datasources/local/pending_sync_delete_local_datasource.dart',
          'lib/data/datasources/local/pending_sync_delete_local_datasource_impl.dart',
        ]),
      );
    });
  });
}
