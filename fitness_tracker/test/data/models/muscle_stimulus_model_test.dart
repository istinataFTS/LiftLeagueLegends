import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/data/models/muscle_stimulus_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 6, 2, 10, 30, 0);

  MuscleStimulusModel buildModel({DateTime? createdAt, DateTime? updatedAt}) {
    final d = createdAt ?? baseDate;
    return MuscleStimulusModel(
      id: 'stim-1',
      ownerUserId: 'user-1',
      muscleGroup: 'chest',
      date: DateTime(2026, 6, 2),
      dailyStimulus: 5.0,
      rollingWeeklyLoad: 12.0,
      createdAt: d,
      updatedAt: updatedAt ?? d,
    );
  }

  group('MuscleStimulusModel.toMap', () {
    test('createdAt is Z-suffixed', () {
      final map = buildModel().toMap();
      expect(
        (map[DatabaseTables.stimulusCreatedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('updatedAt is Z-suffixed', () {
      final map = buildModel().toMap();
      expect(
        (map[DatabaseTables.stimulusUpdatedAt] as String).endsWith('Z'),
        isTrue,
      );
    });
  });

  group('MuscleStimulusModel.fromMap round-trip', () {
    test('createdAt round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = MuscleStimulusModel.fromMap(model.toMap());
      expect(roundTripped.createdAt.isAtSameMomentAs(model.createdAt), isTrue);
      expect(roundTripped.createdAt.isUtc, isFalse);
    });

    test('updatedAt round-trips to same instant and is local', () {
      final model = buildModel(
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );
      final roundTripped = MuscleStimulusModel.fromMap(model.toMap());
      expect(roundTripped.updatedAt.isAtSameMomentAs(model.updatedAt), isTrue);
      expect(roundTripped.updatedAt.isUtc, isFalse);
    });

    test('Z-suffix stored createdAt parses to correct local instant', () {
      final utcInstant = DateTime.utc(2026, 6, 2, 7, 30);
      final map = buildModel(createdAt: utcInstant.toLocal()).toMap();
      map[DatabaseTables.stimulusCreatedAt] = '2026-06-02T07:30:00.000Z';
      final parsed = MuscleStimulusModel.fromMap(map);
      expect(parsed.createdAt.isAtSameMomentAs(utcInstant), isTrue);
      expect(parsed.createdAt.isUtc, isFalse);
    });
  });

  group('MuscleStimulusModel.toJson / fromJson', () {
    test('toJson createdAt is Z-suffixed', () {
      final json = buildModel().toJson();
      expect((json['createdAt'] as String).endsWith('Z'), isTrue);
    });

    test('fromJson createdAt round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = MuscleStimulusModel.fromJson(model.toJson());
      expect(roundTripped.createdAt.isAtSameMomentAs(model.createdAt), isTrue);
      expect(roundTripped.createdAt.isUtc, isFalse);
    });
  });
}
