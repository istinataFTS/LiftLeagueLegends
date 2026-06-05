import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/data/models/muscle_stimulus_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 6, 2, 10, 30, 0);

  MuscleStimulusModel buildModel({
    DateTime? createdAt,
    DateTime? updatedAt,
    double dailyVolume = 0.0,
    double fatigueScore = 0.0,
    int? fatigueAnchorTimestamp,
  }) {
    final d = createdAt ?? baseDate;
    return MuscleStimulusModel(
      id: 'stim-1',
      ownerUserId: 'user-1',
      muscleGroup: 'chest',
      date: DateTime(2026, 6, 2),
      dailyStimulus: 5.0,
      rollingWeeklyLoad: 12.0,
      dailyVolume: dailyVolume,
      fatigueScore: fatigueScore,
      fatigueAnchorTimestamp: fatigueAnchorTimestamp,
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

  group('MuscleStimulusModel dailyVolume', () {
    test('toMap / fromMap round-trips a non-zero dailyVolume', () {
      final model = buildModel(dailyVolume: 4800.0);
      final roundTripped = MuscleStimulusModel.fromMap(model.toMap());
      expect(roundTripped.dailyVolume, closeTo(4800.0, 0.001));
    });

    test('fromMap tolerates a missing daily_volume key (legacy row → 0.0)', () {
      final map = buildModel().toMap()
        ..remove(DatabaseTables.stimulusDailyVolume);
      final parsed = MuscleStimulusModel.fromMap(map);
      expect(parsed.dailyVolume, closeTo(0.0, 0.001));
    });

    test('toJson / fromJson round-trips a non-zero dailyVolume', () {
      final model = buildModel(dailyVolume: 1234.5);
      final roundTripped = MuscleStimulusModel.fromJson(model.toJson());
      expect(roundTripped.dailyVolume, closeTo(1234.5, 0.001));
    });

    test(
      'fromJson tolerates a missing dailyVolume key (legacy JSON → 0.0)',
      () {
        final json = buildModel().toJson()..remove('dailyVolume');
        final parsed = MuscleStimulusModel.fromJson(json);
        expect(parsed.dailyVolume, closeTo(0.0, 0.001));
      },
    );

    test('fromEntity preserves dailyVolume', () {
      final entity = buildModel(dailyVolume: 999.0);
      final fromEntity = MuscleStimulusModel.fromEntity(entity);
      expect(fromEntity.dailyVolume, closeTo(999.0, 0.001));
    });
  });

  group('MuscleStimulusModel fatigueScore', () {
    test('toMap / fromMap round-trips a non-zero fatigueScore', () {
      final model = buildModel(fatigueScore: 42.5);
      final roundTripped = MuscleStimulusModel.fromMap(model.toMap());
      expect(roundTripped.fatigueScore, closeTo(42.5, 0.001));
    });

    test(
      'fromMap tolerates a missing fatigue_score key (legacy row → 0.0)',
      () {
        final map = buildModel().toMap()
          ..remove(DatabaseTables.stimulusFatigueScore);
        final parsed = MuscleStimulusModel.fromMap(map);
        expect(parsed.fatigueScore, closeTo(0.0, 0.001));
      },
    );

    test('toJson / fromJson round-trips a non-zero fatigueScore', () {
      final model = buildModel(fatigueScore: 78.3);
      final roundTripped = MuscleStimulusModel.fromJson(model.toJson());
      expect(roundTripped.fatigueScore, closeTo(78.3, 0.001));
    });

    test(
      'fromJson tolerates a missing fatigueScore key (legacy JSON → 0.0)',
      () {
        final json = buildModel().toJson()..remove('fatigueScore');
        final parsed = MuscleStimulusModel.fromJson(json);
        expect(parsed.fatigueScore, closeTo(0.0, 0.001));
      },
    );

    test('fromEntity preserves fatigueScore', () {
      final entity = buildModel(fatigueScore: 55.0);
      final fromEntity = MuscleStimulusModel.fromEntity(entity);
      expect(fromEntity.fatigueScore, closeTo(55.0, 0.001));
    });
  });

  group('MuscleStimulusModel fatigueAnchorTimestamp', () {
    final anchorMs = DateTime(2026, 6, 2).millisecondsSinceEpoch;

    test('toMap / fromMap round-trips a non-null fatigueAnchorTimestamp', () {
      final model = buildModel(fatigueAnchorTimestamp: anchorMs);
      final roundTripped = MuscleStimulusModel.fromMap(model.toMap());
      expect(roundTripped.fatigueAnchorTimestamp, anchorMs);
    });

    test(
      'fromMap tolerates a missing fatigue_anchor_ts key (legacy row → null)',
      () {
        final map = buildModel(fatigueAnchorTimestamp: anchorMs).toMap()
          ..remove(DatabaseTables.stimulusFatigueAnchorTs);
        final parsed = MuscleStimulusModel.fromMap(map);
        expect(parsed.fatigueAnchorTimestamp, isNull);
      },
    );

    test('fromMap null fatigue_anchor_ts survives as null', () {
      final map = buildModel().toMap();
      final parsed = MuscleStimulusModel.fromMap(map);
      expect(parsed.fatigueAnchorTimestamp, isNull);
    });

    test('toJson / fromJson round-trips a non-null fatigueAnchorTimestamp', () {
      final model = buildModel(fatigueAnchorTimestamp: anchorMs);
      final roundTripped = MuscleStimulusModel.fromJson(model.toJson());
      expect(roundTripped.fatigueAnchorTimestamp, anchorMs);
    });

    test(
      'fromJson tolerates a missing fatigueAnchorTimestamp key (legacy JSON → null)',
      () {
        final json = buildModel(fatigueAnchorTimestamp: anchorMs).toJson()
          ..remove('fatigueAnchorTimestamp');
        final parsed = MuscleStimulusModel.fromJson(json);
        expect(parsed.fatigueAnchorTimestamp, isNull);
      },
    );

    test('fromEntity preserves fatigueAnchorTimestamp', () {
      final entity = buildModel(fatigueAnchorTimestamp: anchorMs);
      final fromEntity = MuscleStimulusModel.fromEntity(entity);
      expect(fromEntity.fatigueAnchorTimestamp, anchorMs);
    });

    test('fromEntity preserves null fatigueAnchorTimestamp', () {
      final entity = buildModel();
      final fromEntity = MuscleStimulusModel.fromEntity(entity);
      expect(fromEntity.fatigueAnchorTimestamp, isNull);
    });
  });
}
