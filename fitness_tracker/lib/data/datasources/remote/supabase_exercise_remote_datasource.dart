import '../../../core/errors/sync_exceptions.dart';
import '../../../domain/entities/exercise.dart';
import '../../dtos/supabase/supabase_exercise_dto.dart';
import 'exercise_remote_datasource.dart';
import 'remote_datasource_guard.dart';
import 'supabase_client_provider.dart';

class SupabaseExerciseRemoteDataSource implements ExerciseRemoteDataSource {
  static const String _tableName = 'exercises';
  static const String _userIdColumn = 'user_id';

  const SupabaseExerciseRemoteDataSource({required this.clientProvider});

  final SupabaseClientProvider clientProvider;

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<List<Exercise>> getAllExercises() {
    return RemoteDatasourceGuard.run(() async {
      final userId = _currentUserIdOrNull();
      if (userId == null) {
        return const <Exercise>[];
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
  Future<Exercise?> getExerciseById(String id) {
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
  Future<Exercise?> getExerciseByName(String name) {
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
  Future<List<Exercise>> getExercisesForMuscle(String muscleGroup) {
    return RemoteDatasourceGuard.run(() async {
      final exercises = await getAllExercises();
      return exercises
          .where((exercise) => exercise.muscleGroups.contains(muscleGroup))
          .toList();
    });
  }

  @override
  Future<Exercise> upsertExercise(Exercise exercise) {
    return RemoteDatasourceGuard.run(() async {
      final userId = _requireAuthenticatedUserId();

      final dto = SupabaseExerciseDto.fromEntity(exercise);
      final payload = <String, dynamic>{...dto.toMap(), _userIdColumn: userId};

      // Conflict on the server's UNIQUE(user_id, name), not just the PK.
      // A stale-id row with the same (user_id, name) is UPDATEd in place
      // instead of raising 23505 — making the push idempotent for default
      // rows (whose id is deterministic since db v21) and robust for any
      // user-renamed exercise that collides by name.
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
  Future<void> deleteExercise({required String localId, String? serverId}) {
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
  Future<List<Exercise>> fetchSince({required String userId, DateTime? since}) {
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

  Exercise _mapRowToEntity(Map<String, dynamic> row) {
    final dto = SupabaseExerciseDto.fromMap(row);
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
        'unauthenticated: exercise remote access requires an authenticated user',
      );
    }

    return userId;
  }
}
