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

  Future<String> callResolveOwnerId() => resolveOwnerId();

  Future<String> callRequireAuthenticatedOwnerId() =>
      requireAuthenticatedOwnerId(operation: 'test-operation');

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

  group('UserScopedLocalDatasource.resolveOwnerId', () {
    test(
      'returns the guest sentinel (empty string) for a guest session',
      () async {
        when(() => mockResolver.resolve()).thenAnswer((_) async => '');

        final id = await datasource.callResolveOwnerId();

        expect(id, equals(''));
      },
    );

    test('returns the user id for an authenticated session', () async {
      when(() => mockResolver.resolve()).thenAnswer((_) async => 'user-abc');

      final id = await datasource.callResolveOwnerId();

      expect(id, equals('user-abc'));
    });
  });

  group('UserScopedLocalDatasource.requireAuthenticatedOwnerId', () {
    test('throws MissingUserContextException when session is guest', () async {
      when(() => mockResolver.resolve()).thenAnswer((_) async => '');

      await expectLater(
        datasource.callRequireAuthenticatedOwnerId(),
        throwsA(
          isA<MissingUserContextException>().having(
            (e) => e.operation,
            'operation',
            'test-operation',
          ),
        ),
      );
    });

    test('returns the user id when session is authenticated', () async {
      when(() => mockResolver.resolve()).thenAnswer((_) async => 'user-xyz');

      final id = await datasource.callRequireAuthenticatedOwnerId();

      expect(id, equals('user-xyz'));
    });
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
