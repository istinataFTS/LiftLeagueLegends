import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/errors/repository_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepositoryGuard', () {
    test('returns Right when action succeeds', () async {
      final Either<Failure, int> result = await RepositoryGuard.run(
        () async => 42,
      );

      expect(result, const Right<Failure, int>(42));
    });

    test('maps ValidationException through RepositoryErrorMapper', () async {
      final Either<Failure, void> result = await RepositoryGuard.run(
        () async => throw const ValidationException('invalid payload'),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid payload')),
      );
    });

    test('maps CacheDatabaseException through RepositoryErrorMapper', () async {
      final Either<Failure, void> result = await RepositoryGuard.run(
        () async => throw const CacheDatabaseException('database unavailable'),
      );

      expect(
        result,
        const Left<Failure, void>(DatabaseFailure('database unavailable')),
      );
    });

    test('maps CacheException through RepositoryErrorMapper', () async {
      final Either<Failure, void> result = await RepositoryGuard.run(
        () async => throw const CacheException('cache unavailable'),
      );

      expect(
        result,
        const Left<Failure, void>(CacheFailure('cache unavailable')),
      );
    });

    test('maps unknown errors to UnexpectedFailure', () async {
      final Either<Failure, void> result = await RepositoryGuard.run(
        () async => throw StateError('unexpected'),
      );

      expect(
        result,
        const Left<Failure, void>(
          UnexpectedFailure('Unexpected error: Bad state: unexpected'),
        ),
      );
    });
  });
}
