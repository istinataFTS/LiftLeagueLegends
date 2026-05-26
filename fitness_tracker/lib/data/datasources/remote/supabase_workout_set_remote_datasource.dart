import '../../../core/errors/sync_exceptions.dart';
import '../../../domain/entities/workout_set.dart';
import '../../dtos/supabase/supabase_workout_set_dto.dart';
import 'remote_datasource_guard.dart';
import 'supabase_client_provider.dart';
import 'workout_set_remote_datasource.dart';

class SupabaseWorkoutSetRemoteDataSource implements WorkoutSetRemoteDataSource {
  static const String _tableName = 'workout_sets';
  static const String _userIdColumn = 'user_id';

  final SupabaseClientProvider clientProvider;

  const SupabaseWorkoutSetRemoteDataSource({required this.clientProvider});

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<List<WorkoutSet>> getAllSets() {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <WorkoutSet>[];
      }

      final dynamic data = await clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId)
          .order('performed_at', ascending: false);

      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  @override
  Future<WorkoutSet?> getSetById(String id) {
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
  Future<WorkoutSet> upsertSet(WorkoutSet set) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _requireAuthenticatedUserId();

      final dto = SupabaseWorkoutSetDto.fromEntity(set);
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
  Future<void> deleteSet({required String localId, String? serverId}) {
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
  Future<List<WorkoutSet>> fetchSince({
    required String userId,
    DateTime? since,
  }) {
    return RemoteDatasourceGuard.run(() async {
      var query = clientProvider.client
          .from(_tableName)
          .select()
          .eq(_userIdColumn, userId);

      if (since != null) {
        query = query.gt('updated_at', since.toIso8601String());
      }

      final dynamic data = await query.order('updated_at', ascending: false);
      final rows = _asMapList(data);
      return rows.map(_mapRowToEntity).toList();
    });
  }

  WorkoutSet _mapRowToEntity(Map<String, dynamic> row) {
    final dto = SupabaseWorkoutSetDto.fromMap(row);
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
        'unauthenticated: workout set remote access requires an authenticated user',
      );
    }

    return userId;
  }
}
