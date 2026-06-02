import 'package:fitness_tracker/data/dtos/supabase/supabase_workout_set_dto.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime performedAt = DateTime(2026, 6, 2, 10, 30, 0);
  final DateTime createdAt = DateTime(2026, 6, 2, 10, 0, 0);
  final DateTime updatedAt = DateTime(2026, 6, 2, 10, 30, 0);

  Map<String, dynamic> buildMap({
    String performedAtStr = '2026-06-02T07:30:00.000Z',
    String createdAtStr = '2026-06-02T07:00:00.000Z',
    String updatedAtStr = '2026-06-02T07:30:00.000Z',
  }) {
    return {
      'id': 'srv-1',
      'user_id': 'user-1',
      'exercise_id': 'bench',
      'reps': 10,
      'weight': 80.0,
      'intensity': 8,
      'performed_at': performedAtStr,
      'created_at': createdAtStr,
      'updated_at': updatedAtStr,
    };
  }

  WorkoutSet buildEntity() {
    return WorkoutSet(
      id: 'local-1',
      ownerUserId: 'user-1',
      exerciseId: 'bench',
      reps: 10,
      weight: 80.0,
      intensity: 8,
      date: performedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncMetadata: const EntitySyncMetadata(serverId: 'srv-1'),
    );
  }

  group('SupabaseWorkoutSetDto.fromMap', () {
    test('parses Z strings to local DateTimes', () {
      final dto = SupabaseWorkoutSetDto.fromMap(buildMap());
      expect(dto.performedAt.isUtc, isFalse);
      expect(dto.createdAt.isUtc, isFalse);
      expect(dto.updatedAt.isUtc, isFalse);
    });

    test('preserves the correct instant from a Z string', () {
      final dto = SupabaseWorkoutSetDto.fromMap(buildMap());
      expect(
        dto.performedAt.isAtSameMomentAs(DateTime.utc(2026, 6, 2, 7, 30)),
        isTrue,
      );
    });
  });

  group('SupabaseWorkoutSetDto.toMap', () {
    test('performed_at is Z-suffixed', () {
      final dto = SupabaseWorkoutSetDto.fromEntity(buildEntity());
      final map = dto.toMap();
      expect((map['performed_at'] as String).endsWith('Z'), isTrue);
    });

    test('created_at is Z-suffixed', () {
      final dto = SupabaseWorkoutSetDto.fromEntity(buildEntity());
      final map = dto.toMap();
      expect((map['created_at'] as String).endsWith('Z'), isTrue);
    });

    test('updated_at is Z-suffixed', () {
      final dto = SupabaseWorkoutSetDto.fromEntity(buildEntity());
      final map = dto.toMap();
      expect((map['updated_at'] as String).endsWith('Z'), isTrue);
    });
  });

  group('SupabaseWorkoutSetDto round-trip (fromMap → toMap)', () {
    test('performedAt instant survives the round-trip', () {
      final utcSource = DateTime.utc(2026, 6, 2, 7, 30);
      final dto = SupabaseWorkoutSetDto.fromMap(buildMap());
      final reMap = dto.toMap();
      final reParsed = SupabaseWorkoutSetDto.fromMap(reMap);
      expect(reParsed.performedAt.isAtSameMomentAs(utcSource), isTrue);
    });
  });
}
