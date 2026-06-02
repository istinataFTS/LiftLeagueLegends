import '../../../core/errors/sync_exceptions.dart';
import '../../../core/utils/date_serialization.dart';
import '../../../domain/entities/nutrition_log.dart';
import '../../dtos/supabase/supabase_nutrition_log_dto.dart';
import 'nutrition_log_remote_datasource.dart';
import 'remote_datasource_guard.dart';
import 'supabase_client_provider.dart';

class SupabaseNutritionLogRemoteDataSource
    implements NutritionLogRemoteDataSource {
  static const String _tableName = 'nutrition_logs';
  static const String _userIdColumn = 'user_id';
  static const String _loggedAtColumn = 'logged_at';

  final SupabaseClientProvider clientProvider;

  const SupabaseNutritionLogRemoteDataSource({required this.clientProvider});

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<List<NutritionLog>> getAllLogs() {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <NutritionLog>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .order(_loggedAtColumn, ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<NutritionLog?> getLogById(String id) {
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
  Future<List<NutritionLog>> getLogsByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return getLogsByDateRange(start, end);
  }

  @override
  Future<List<NutritionLog>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <NutritionLog>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .gte(_loggedAtColumn, startDate.toStorageIso())
          .lt(_loggedAtColumn, endDate.toStorageIso())
          .order(_loggedAtColumn, ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<List<NutritionLog>> getLogsByMealId(String mealId) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <NutritionLog>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .eq('meal_id', mealId)
          .order(_loggedAtColumn, ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<NutritionLog> upsertLog(NutritionLog log) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _requireAuthenticatedUserId();

      final dto = SupabaseNutritionLogDto.fromEntity(log);
      final payload = <String, dynamic>{...dto.toMap(), _userIdColumn: userId};

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .upsert(payload)
          .select()
          .single();

      final row = Map<String, dynamic>.from(data as Map);
      return _mapRowToEntity(row);
    });
  }

  @override
  Future<void> deleteLog({required String localId, String? serverId}) {
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
  Future<List<NutritionLog>> fetchSince({
    required String userId,
    DateTime? since,
  }) {
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

  NutritionLog _mapRowToEntity(Map<String, dynamic> row) {
    final dto = SupabaseNutritionLogDto.fromMap(row);
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
        'unauthenticated: nutrition log remote access requires an authenticated user',
      );
    }

    return userId;
  }
}
