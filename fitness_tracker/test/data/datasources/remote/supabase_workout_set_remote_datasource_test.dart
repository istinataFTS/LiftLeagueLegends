import 'package:fitness_tracker/core/utils/date_serialization.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_client_provider.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_workout_set_remote_datasource.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_workout_set_dto.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  WorkoutSet buildWorkoutSet({
    required String id,
    String exerciseId = 'bench-1',
    String ownerUserId = 'user-1',
    DateTime? date,
  }) {
    final d = date ?? baseDate;
    return WorkoutSet(
      id: id,
      exerciseId: exerciseId,
      ownerUserId: ownerUserId,
      reps: 10,
      weight: 80,
      intensity: 8,
      date: d,
      createdAt: d,
      updatedAt: d,
      syncMetadata: const EntitySyncMetadata(),
    );
  }

  group('SupabaseWorkoutSetRemoteDataSource', () {
    test('reports configured state from provider', () {
      const dataSource = SupabaseWorkoutSetRemoteDataSource(
        clientProvider: SupabaseClientProvider(isConfigured: true),
      );

      expect(dataSource.isConfigured, isTrue);
    });

    test('reports unconfigured state from provider', () {
      const dataSource = SupabaseWorkoutSetRemoteDataSource(
        clientProvider: SupabaseClientProvider(isConfigured: false),
      );

      expect(dataSource.isConfigured, isFalse);
    });

    test('throws StateError when unconfigured provider client is accessed', () {
      const provider = SupabaseClientProvider(isConfigured: false);

      expect(() => provider.client, throwsStateError);
    });

    test('fetchByDateRange bounds serialise to UTC Z-suffixed strings', () {
      final DateTime start = DateTime(2026, 3, 22, 0, 0);
      final DateTime end = DateTime(2026, 3, 22, 23, 59, 59);

      final String startIso = start.toStorageIso();
      final String endIso = end.toStorageIso();

      expect(startIso, endsWith('Z'));
      expect(endIso, endsWith('Z'));
      expect(DateTime.parse(startIso).isAtSameMomentAs(start), isTrue);
      expect(DateTime.parse(endIso).isAtSameMomentAs(end), isTrue);
    });

    test('DTO round-trips performed_at as UTC Z-suffixed string', () {
      final WorkoutSet set = buildWorkoutSet(id: 'set-1');
      final Map<String, dynamic> map = SupabaseWorkoutSetDto.fromEntity(
        set,
      ).toMap();

      expect(map['performed_at'], isA<String>());
      expect((map['performed_at'] as String), endsWith('Z'));
      expect(
        DateTime.parse(
          map['performed_at'] as String,
        ).isAtSameMomentAs(set.date),
        isTrue,
      );
    });

    test('DTO payload includes user_id and performed_at columns', () {
      final WorkoutSet set = buildWorkoutSet(id: 'set-1');
      final Map<String, dynamic> map = SupabaseWorkoutSetDto.fromEntity(
        set,
      ).toMap();

      expect(map.containsKey('performed_at'), isTrue);
      expect(map.containsKey('exercise_id'), isTrue);
    });
  });
}
