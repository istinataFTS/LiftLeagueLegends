import '../../../core/errors/sync_exceptions.dart';
import '../../../core/utils/date_serialization.dart';
import '../../../domain/entities/meal.dart';
import '../../dtos/supabase/supabase_meal_dto.dart';
import 'meal_remote_datasource.dart';
import 'remote_datasource_guard.dart';
import 'supabase_client_provider.dart';

class SupabaseMealRemoteDataSource implements MealRemoteDataSource {
  static const String _tableName = 'meals';
  static const String _userIdColumn = 'user_id';

  final SupabaseClientProvider clientProvider;

  const SupabaseMealRemoteDataSource({required this.clientProvider});

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<List<Meal>> getAllMeals() {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <Meal>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .order('updated_at', ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<Meal?> getMealById(String id) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return null;
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .eq('id', id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return _mapRowToEntity(Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  Future<Meal?> getMealByName(String name) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return null;
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .eq('name', name)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return _mapRowToEntity(Map<String, dynamic>.from(data as Map));
    });
  }

  @override
  Future<List<Meal>> searchMealsByName(String searchTerm) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <Meal>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .ilike('name', '%$searchTerm%')
          .order('updated_at', ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<Meal> upsertMeal(Meal meal) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _requireAuthenticatedUserId();

      final dto = SupabaseMealDto.fromEntity(meal);
      final payload = <String, dynamic>{...dto.toMap(), _userIdColumn: userId};

      // Conflict on the server's UNIQUE(user_id, name), not just the PK —
      // same rationale as exercises: idempotent for deterministic default
      // ids (db v21) and robust against any (user_id, name) collision.
      final dynamic data = await clientProvider.client
          .from(_tableName)
          .upsert(payload, onConflict: 'user_id,name')
          .select()
          .single();

      final row = Map<String, dynamic>.from(data as Map);
      return _mapRowToEntity(row);
    });
  }

  @override
  Future<void> deleteMeal({required String localId, String? serverId}) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _requireAuthenticatedUserId();
      final remoteId = serverId ?? localId;

      await clientProvider.client
          .from(_tableName)
          .delete()
          .eq(_userIdColumn, userId)
          .eq('id', remoteId);
    });
  }

  @override
  Future<List<Meal>> fetchSince({required String userId, DateTime? since}) {
    return RemoteDatasourceGuard.run(() async {
      var query = clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId);

      if (since != null) {
        query = query.gt('updated_at', since.toStorageIso());
      }

      final dynamic data = await query.order('updated_at', ascending: false);
      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  Meal _mapRowToEntity(Map<String, dynamic> row) {
    final dto = SupabaseMealDto.fromMap(row);
    return dto.toEntity(localId: dto.id, syncMetadata: dto.toSyncedMetadata());
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    final list = data as List<dynamic>;
    return list
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  String? _currentUserIdOrNull() {
    if (!isConfigured) {
      return null;
    }

    return clientProvider.client.auth.currentUser?.id;
  }

  String _requireAuthenticatedUserId() {
    final userId = _currentUserIdOrNull();
    if (userId == null || userId.isEmpty) {
      throw const AuthSyncException(
        'unauthenticated: meal remote access requires an authenticated user',
      );
    }

    return userId;
  }
}
