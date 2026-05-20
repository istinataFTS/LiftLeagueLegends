// Common, lightweight exceptions used across the data layer.
//
// Each subclass carries a free-form `message` and overrides `toString` so
// log lines like `[ERROR][sync] error: $exception` print the wrapped detail
// instead of an opaque `Instance of 'CacheDatabaseException'`. Without the
// override Dart's default `Object.toString` returns the type name only,
// which silently hides root causes (e.g. a UNIQUE-constraint trip).

class CacheDatabaseException implements Exception {
  const CacheDatabaseException(this.message);

  final String message;

  @override
  String toString() => 'CacheDatabaseException: $message';
}

class CacheException implements Exception {
  const CacheException(this.message);

  final String message;

  @override
  String toString() => 'CacheException: $message';
}

class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown by [UserScopedLocalDatasource.requireAuthenticatedOwnerId] when
/// an auth-only datasource operation is invoked during a guest session.
class MissingUserContextException implements Exception {
  const MissingUserContextException({required this.operation});

  final String operation;

  @override
  String toString() =>
      'MissingUserContextException(operation: $operation): cannot run in guest mode';
}
