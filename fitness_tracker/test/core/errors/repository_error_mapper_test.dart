import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/errors/repository_error_mapper.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/core/errors/sync_failures.dart';
import 'package:fitness_tracker/data/sync/entity_sync_batch_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositoryErrorMapper', () {
    test('maps ValidationException to ValidationFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const ValidationException('invalid input'),
      );

      expect(result, const ValidationFailure('invalid input'));
    });

    test('maps CacheDatabaseException to DatabaseFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const CacheDatabaseException('db failed'),
      );

      expect(result, const DatabaseFailure('db failed'));
    });

    test('maps CacheException to CacheFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const CacheException('cache failed'),
      );

      expect(result, const CacheFailure('cache failed'));
    });

    test('maps ArgumentError to ValidationFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        ArgumentError('bad argument'),
      );

      expect(result, const ValidationFailure('bad argument'));
    });

    test('maps NetworkSyncException to NetworkSyncFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const NetworkSyncException('no connection'),
      );

      expect(result, const NetworkSyncFailure('no connection'));
    });

    test('maps AuthSyncException to AuthSyncFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const AuthSyncException('token expired'),
      );

      expect(result, const AuthSyncFailure('token expired'));
    });

    test('maps RemoteSyncException to RemoteSyncFailure', () {
      final Failure result = RepositoryErrorMapper.map(
        const RemoteSyncException('constraint violation'),
      );

      expect(result, const RemoteSyncFailure('constraint violation'));
    });

    test('maps EntitySyncBatchFailure to BatchSyncFailure with entity ids', () {
      final Failure result = RepositoryErrorMapper.map(
        const EntitySyncBatchFailure(
          entityLabel: 'workout_sets',
          failedUpsertEntityIds: ['id-1', 'id-2'],
          failedDeleteEntityIds: ['id-3'],
        ),
      );

      expect(
        result,
        const BatchSyncFailure(
          message:
              'failed to upsert 2 workout_sets entries (id-1, id-2); '
              'failed to delete 1 workout_sets entry (id-3)',
          failedUpsertEntityIds: ['id-1', 'id-2'],
          failedDeleteEntityIds: ['id-3'],
        ),
      );
    });

    test('maps unknown errors to UnexpectedFailure', () {
      final Failure result = RepositoryErrorMapper.map(StateError('boom'));

      expect(
        result,
        const UnexpectedFailure('Unexpected error: Bad state: boom'),
      );
    });
  });
}
