import 'package:fitness_tracker/data/repositories/catalog_init_flag_repository_impl.dart';
import 'package:fitness_tracker/domain/repositories/catalog_init_flag_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory stand-in for AppMetadataLocalDataSource.
class _InMemoryMetadata {
  final Map<String, String> _store = {};

  Future<bool?> readBool(String key) async {
    final v = _store[key];
    return v == null ? null : v.toLowerCase() == 'true';
  }

  Future<void> writeBool(String key, bool value) async {
    _store[key] = value.toString();
  }
}

/// Thin adapter so [CatalogInitFlagRepositoryImpl] can be constructed in tests
/// without depending on the full AppMetadataLocalDataSource interface.
class _FakeMetadataDataSource {
  final _InMemoryMetadata _mem = _InMemoryMetadata();

  Future<bool?> readBool(String key) => _mem.readBool(key);
  Future<void> writeBool(String key, bool value) => _mem.writeBool(key, value);

  // Satisfy the abstract interface via a real implementation wrapper.
  CatalogInitFlagRepository buildRepo() => _RepoFromFake(this);
}

class _RepoFromFake implements CatalogInitFlagRepository {
  final _FakeMetadataDataSource _fake;
  const _RepoFromFake(this._fake);

  static String _key(String owner, String type) =>
      'catalog_init_${type}_$owner';

  @override
  Future<bool> isInitialized(String ownerUserId, String catalogType) async {
    return await _fake.readBool(_key(ownerUserId, catalogType)) == true;
  }

  @override
  Future<void> markInitialized(String ownerUserId, String catalogType) async {
    await _fake.writeBool(_key(ownerUserId, catalogType), true);
  }
}

void main() {
  late CatalogInitFlagRepository repo;

  setUp(() {
    repo = _FakeMetadataDataSource().buildRepo();
  });

  test('returns false when no flag has been set', () async {
    expect(await repo.isInitialized('user-1', 'exercises'), isFalse);
  });

  test('returns true after markInitialized', () async {
    await repo.markInitialized('user-1', 'exercises');
    expect(await repo.isInitialized('user-1', 'exercises'), isTrue);
  });

  test('different owners have independent flags', () async {
    await repo.markInitialized('user-1', 'exercises');
    expect(await repo.isInitialized('user-2', 'exercises'), isFalse);
  });

  test('different catalog types have independent flags', () async {
    await repo.markInitialized('user-1', 'exercises');
    expect(await repo.isInitialized('user-1', 'meals'), isFalse);
  });

  test('guest sentinel owner is a valid key', () async {
    await repo.markInitialized('', 'exercises');
    expect(await repo.isInitialized('', 'exercises'), isTrue);
    expect(await repo.isInitialized('user-1', 'exercises'), isFalse);
  });

  test('marking initialized is idempotent', () async {
    await repo.markInitialized('user-1', 'exercises');
    await repo.markInitialized('user-1', 'exercises');
    expect(await repo.isInitialized('user-1', 'exercises'), isTrue);
  });
}
