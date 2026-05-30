import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/user_scoped_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockCurrentUserIdResolver extends Mock implements CurrentUserIdResolver {}

/// Minimal concrete subclass used to exercise the base-class helpers.
class _TestDatasource extends UserScopedLocalDatasource {
  _TestDatasource({
    required super.databaseHelper,
    required super.currentUserIdResolver,
  });

  Future<String> callOwnerId() => ownerId();

  ({String where, List<Object?> whereArgs}) callWhereOwned({
    required String ownerId,
    String? extra,
    List<Object?> extraArgs = const [],
  }) => whereOwned(ownerId: ownerId, extra: extra, extraArgs: extraArgs);
}

void main() {
  late MockDatabaseHelper databaseHelper;
  late MockCurrentUserIdResolver mockResolver;
  late _TestDatasource datasource;

  setUp(() {
    databaseHelper = MockDatabaseHelper();
    mockResolver = MockCurrentUserIdResolver();
    datasource = _TestDatasource(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockResolver,
    );
  });

  group('UserScopedLocalDatasource.ownerId', () {
    test('returns the user id when the resolver yields one', () async {
      when(() => mockResolver.resolve()).thenAnswer((_) async => 'user-xyz');

      final id = await datasource.callOwnerId();

      expect(id, equals('user-xyz'));
    });

    test(
      'propagates MissingUserContextException when the resolver throws',
      () async {
        when(() => mockResolver.resolve()).thenAnswer(
          (_) async => throw const MissingUserContextException(
            operation: 'session lookup',
          ),
        );

        await expectLater(
          datasource.callOwnerId(),
          throwsA(
            isA<MissingUserContextException>().having(
              (e) => e.operation,
              'operation',
              'session lookup',
            ),
          ),
        );
      },
    );
  });

  group('UserScopedLocalDatasource.whereOwned', () {
    test('builds owner-only clause when no extra condition is given', () {
      final result = datasource.callWhereOwned(ownerId: 'u1');

      expect(result.where, equals('owner_user_id = ?'));
      expect(result.whereArgs, equals(<Object?>['u1']));
    });

    test('composes extra clause with owner as the final predicate', () {
      final result = datasource.callWhereOwned(
        ownerId: 'u1',
        extra: 'sync_status != ?',
        extraArgs: ['pendingDelete'],
      );

      expect(result.where, equals('(sync_status != ?) AND owner_user_id = ?'));
      expect(result.whereArgs, equals(<Object?>['pendingDelete', 'u1']));
    });
  });
}
