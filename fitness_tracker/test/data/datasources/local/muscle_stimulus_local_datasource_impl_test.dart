import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/muscle_stimulus_local_datasource.dart';
import 'package:fitness_tracker/data/models/muscle_stimulus_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockCurrentUserIdResolver extends Mock implements CurrentUserIdResolver {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MockDatabaseHelper databaseHelper;
  late MockCurrentUserIdResolver mockResolver;
  late MuscleStimulusLocalDataSourceImpl dataSource;

  const String userA = 'user-a';
  const String userB = 'user-b';

  final DateTime baseDate = DateTime(2026, 4, 7);
  final DateTime yesterday = DateTime(2026, 4, 6);
  final DateTime twoDaysAgo = DateTime(2026, 4, 5);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  MuscleStimulusModel buildStimulus({
    required String id,
    required String ownerUserId,
    String muscleGroup = 'chest',
    DateTime? date,
    double dailyStimulus = 5.0,
    double rollingWeeklyLoad = 10.0,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  }) {
    final d = date ?? baseDate;
    return MuscleStimulusModel(
      id: id,
      ownerUserId: ownerUserId,
      muscleGroup: muscleGroup,
      date: d,
      dailyStimulus: dailyStimulus,
      rollingWeeklyLoad: rollingWeeklyLoad,
      lastSetTimestamp: lastSetTimestamp,
      lastSetStimulus: lastSetStimulus,
      createdAt: d,
      updatedAt: d,
    );
  }

  Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.muscleStimulus} (
        ${DatabaseTables.stimulusId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT NOT NULL DEFAULT '',
        ${DatabaseTables.stimulusMuscleGroup} TEXT NOT NULL,
        ${DatabaseTables.stimulusDate} TEXT NOT NULL,
        ${DatabaseTables.stimulusDailyStimulus} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseTables.stimulusRollingWeeklyLoad} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseTables.stimulusLastSetTimestamp} INTEGER,
        ${DatabaseTables.stimulusLastSetStimulus} REAL,
        ${DatabaseTables.stimulusDailyVolume} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseTables.stimulusCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.stimulusUpdatedAt} TEXT NOT NULL,
        UNIQUE(${DatabaseTables.ownerUserId}, ${DatabaseTables.stimulusMuscleGroup}, ${DatabaseTables.stimulusDate})
      )
    ''');
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async => createSchema(db),
      ),
    );

    databaseHelper = MockDatabaseHelper();
    when(() => databaseHelper.database).thenAnswer((_) async => database);

    mockResolver = MockCurrentUserIdResolver();
    when(() => mockResolver.resolve()).thenAnswer((_) async => userA);

    dataSource = MuscleStimulusLocalDataSourceImpl(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockResolver,
    );
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------------------------------
  // User isolation — getStimulusByMuscleAndDate
  // ---------------------------------------------------------------------------

  group('getStimulusByMuscleAndDate user isolation', () {
    test('returns record for the correct user', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'stim-a', ownerUserId: userA),
      );

      final result = await dataSource.getStimulusByMuscleAndDate(
        muscleGroup: 'chest',
        date: baseDate,
      );

      expect(result, isNotNull);
      expect(result!.id, 'stim-a');
      expect(result.ownerUserId, userA);
    });

    test('returns nothing for user B when only user A has data', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'stim-a', ownerUserId: userA),
      );

      when(() => mockResolver.resolve()).thenAnswer((_) async => userB);

      final result = await dataSource.getStimulusByMuscleAndDate(
        muscleGroup: 'chest',
        date: baseDate,
      );

      expect(result, isNull);
    });

    test(
      'returns null when no record exists for the user on that date',
      () async {
        final result = await dataSource.getStimulusByMuscleAndDate(
          muscleGroup: 'chest',
          date: baseDate,
        );

        expect(result, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // User isolation — getStimulusByDateRange
  // ---------------------------------------------------------------------------

  group('getStimulusByDateRange user isolation', () {
    test('returns only records belonging to the requested user', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'a-today', ownerUserId: userA, date: baseDate),
      );
      await dataSource.upsertStimulus(
        buildStimulus(id: 'a-yesterday', ownerUserId: userA, date: yesterday),
      );
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-today', ownerUserId: userB, date: baseDate),
      );

      final results = await dataSource.getStimulusByDateRange(
        muscleGroup: 'chest',
        startDate: yesterday,
        endDate: baseDate,
      );

      final ids = results.map((r) => r.id).toSet();
      expect(ids, containsAll(<String>['a-today', 'a-yesterday']));
      expect(ids, isNot(contains('b-today')));
    });

    test('returns empty list when user has no data in range', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-today', ownerUserId: userB, date: baseDate),
      );

      final results = await dataSource.getStimulusByDateRange(
        muscleGroup: 'chest',
        startDate: yesterday,
        endDate: baseDate,
      );

      expect(results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // User isolation — getAllStimulusForDate
  // ---------------------------------------------------------------------------

  group('getAllStimulusForDate user isolation', () {
    test('returns all muscle records for user on the given date', () async {
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'a-chest',
          ownerUserId: userA,
          muscleGroup: 'chest',
          date: baseDate,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'a-back',
          ownerUserId: userA,
          muscleGroup: 'back',
          date: baseDate,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'b-chest',
          ownerUserId: userB,
          muscleGroup: 'chest',
          date: baseDate,
        ),
      );

      final results = await dataSource.getAllStimulusForDate(baseDate);
      final ids = results.map((r) => r.id).toSet();

      expect(ids, containsAll(<String>['a-chest', 'a-back']));
      expect(ids, isNot(contains('b-chest')));
    });

    test('returns empty list when user has no records on that date', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-chest', ownerUserId: userB, date: baseDate),
      );

      final results = await dataSource.getAllStimulusForDate(baseDate);
      expect(results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // User isolation — applyDailyDecayToAll
  // ---------------------------------------------------------------------------

  group('applyDailyDecayToAll user isolation', () {
    test('only decays records belonging to the current user', () async {
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'a-chest',
          ownerUserId: userA,
          rollingWeeklyLoad: 10.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'b-chest',
          ownerUserId: userB,
          muscleGroup: 'back',
          rollingWeeklyLoad: 10.0,
        ),
      );

      await dataSource.applyDailyDecayToAll();

      final allRows = await database.query(DatabaseTables.muscleStimulus);
      final byId = {for (final r in allRows) r[DatabaseTables.stimulusId]: r};

      // user A's record should be decayed (10.0 * 0.6 = 6.0)
      expect(
        (byId['a-chest']![DatabaseTables.stimulusRollingWeeklyLoad] as num)
            .toDouble(),
        closeTo(6.0, 0.001),
      );

      // user B's record must remain untouched
      expect(
        (byId['b-chest']![DatabaseTables.stimulusRollingWeeklyLoad] as num)
            .toDouble(),
        closeTo(10.0, 0.001),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // User isolation — getMaxStimulusForMuscle
  // ---------------------------------------------------------------------------

  group('getMaxStimulusForMuscle user isolation', () {
    test('returns max daily stimulus for the current user only', () async {
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'a-chest',
          ownerUserId: userA,
          date: baseDate,
          dailyStimulus: 8.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'b-chest',
          ownerUserId: userB,
          muscleGroup: 'chest',
          date: yesterday,
          dailyStimulus: 20.0,
        ),
      );

      final max = await dataSource.getMaxStimulusForMuscle('chest');

      expect(max, closeTo(8.0, 0.001));
    });

    test('returns 0.0 when user has no records for that muscle', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-chest', ownerUserId: userB, dailyStimulus: 15.0),
      );

      final max = await dataSource.getMaxStimulusForMuscle('chest');
      expect(max, closeTo(0.0, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // User isolation — deleteOlderThan
  // ---------------------------------------------------------------------------

  group('deleteOlderThan user isolation', () {
    test(
      'only deletes records older than the cutoff for the current user',
      () async {
        await dataSource.upsertStimulus(
          buildStimulus(id: 'a-old', ownerUserId: userA, date: twoDaysAgo),
        );
        await dataSource.upsertStimulus(
          buildStimulus(id: 'a-new', ownerUserId: userA, date: baseDate),
        );
        await dataSource.upsertStimulus(
          buildStimulus(id: 'b-old', ownerUserId: userB, date: twoDaysAgo),
        );

        await dataSource.deleteOlderThan(yesterday);

        final allRows = await database.query(DatabaseTables.muscleStimulus);
        final ids = allRows
            .map((r) => r[DatabaseTables.stimulusId] as String)
            .toSet();

        // user A's old record deleted; user A's new record and user B's old record survive
        expect(ids, containsAll(<String>['a-new', 'b-old']));
        expect(ids, isNot(contains('a-old')));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearStimulusForUser
  // ---------------------------------------------------------------------------

  group('clearStimulusForUser', () {
    test('only deletes rows owned by the given userId', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'a-chest', ownerUserId: userA),
      );
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-chest', ownerUserId: userB, muscleGroup: 'back'),
      );

      await dataSource.clearStimulusForUser(userA);

      final allRows = await database.query(DatabaseTables.muscleStimulus);
      final ids = allRows
          .map((r) => r[DatabaseTables.stimulusId] as String)
          .toSet();

      expect(ids, isNot(contains('a-chest')));
      expect(ids, contains('b-chest'));
    });

    test('is a no-op when the user has no records', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'b-chest', ownerUserId: userB),
      );

      await dataSource.clearStimulusForUser(userA);

      final allRows = await database.query(DatabaseTables.muscleStimulus);
      expect(allRows, hasLength(1));
    });

    test(
      'deletes all records for the user across every muscle group',
      () async {
        await dataSource.upsertStimulus(
          buildStimulus(
            id: 'a-chest',
            ownerUserId: userA,
            muscleGroup: 'chest',
          ),
        );
        await dataSource.upsertStimulus(
          buildStimulus(
            id: 'a-back',
            ownerUserId: userA,
            muscleGroup: 'back',
            date: yesterday,
          ),
        );
        await dataSource.upsertStimulus(
          buildStimulus(
            id: 'a-legs',
            ownerUserId: userA,
            muscleGroup: 'quads',
            date: twoDaysAgo,
          ),
        );

        await dataSource.clearStimulusForUser(userA);

        final allRows = await database.query(DatabaseTables.muscleStimulus);
        expect(allRows, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // upsertStimulus / updateStimulusValues (core write behaviour)
  // ---------------------------------------------------------------------------

  group('upsertStimulus', () {
    test('inserts a new record', () async {
      final model = buildStimulus(id: 'stim-1', ownerUserId: userA);
      await dataSource.upsertStimulus(model);

      final result = await dataSource.getStimulusByMuscleAndDate(
        muscleGroup: 'chest',
        date: baseDate,
      );

      expect(result, isNotNull);
      expect(result!.id, 'stim-1');
      expect(result.ownerUserId, userA);
      expect(result.dailyStimulus, 5.0);
    });

    test('replaces an existing record on conflict', () async {
      await dataSource.upsertStimulus(
        buildStimulus(id: 'stim-1', ownerUserId: userA, dailyStimulus: 5.0),
      );
      await dataSource.upsertStimulus(
        buildStimulus(id: 'stim-1', ownerUserId: userA, dailyStimulus: 8.0),
      );

      final result = await dataSource.getStimulusByMuscleAndDate(
        muscleGroup: 'chest',
        date: baseDate,
      );

      expect(result!.dailyStimulus, 8.0);
    });
  });

  group('updateStimulusValues', () {
    test('updates daily stimulus and rolling load for the given id', () async {
      await dataSource.upsertStimulus(
        buildStimulus(
          id: 'stim-1',
          ownerUserId: userA,
          dailyStimulus: 5.0,
          rollingWeeklyLoad: 10.0,
        ),
      );

      await dataSource.updateStimulusValues(
        id: 'stim-1',
        dailyStimulus: 7.0,
        rollingWeeklyLoad: 14.0,
        lastSetTimestamp: 1000,
        lastSetStimulus: 3.0,
      );

      final result = await dataSource.getStimulusByMuscleAndDate(
        muscleGroup: 'chest',
        date: baseDate,
      );

      expect(result!.dailyStimulus, 7.0);
      expect(result.rollingWeeklyLoad, 14.0);
      expect(result.lastSetTimestamp, 1000);
      expect(result.lastSetStimulus, 3.0);
    });
  });

  // ---------------------------------------------------------------------------
  // getTotalVolumeForMuscle
  // ---------------------------------------------------------------------------

  MuscleStimulusModel buildStimulusWithVolume({
    required String id,
    required String ownerUserId,
    String muscleGroup = 'mid-chest',
    required DateTime date,
    double dailyVolume = 0.0,
  }) => MuscleStimulusModel(
    id: id,
    ownerUserId: ownerUserId,
    muscleGroup: muscleGroup,
    date: date,
    dailyStimulus: 1.0,
    rollingWeeklyLoad: 1.0,
    dailyVolume: dailyVolume,
    createdAt: date,
    updatedAt: date,
  );

  group('getTotalVolumeForMuscle', () {
    test('sums daily_volume for the current user, no window', () async {
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-1',
          ownerUserId: userA,
          date: baseDate,
          dailyVolume: 1000.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-2',
          ownerUserId: userA,
          date: yesterday,
          dailyVolume: 500.0,
        ),
      );

      final total = await dataSource.getTotalVolumeForMuscle('mid-chest');
      expect(total, closeTo(1500.0, 0.001));
    });

    test('excludes another user\'s rows', () async {
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-1',
          ownerUserId: userA,
          date: baseDate,
          dailyVolume: 1000.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'b-1',
          ownerUserId: userB,
          date: baseDate,
          dailyVolume: 9999.0,
        ),
      );

      final total = await dataSource.getTotalVolumeForMuscle('mid-chest');
      expect(total, closeTo(1000.0, 0.001));
    });

    test('returns 0.0 when user has no rows for that muscle', () async {
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-back',
          ownerUserId: userA,
          muscleGroup: 'lats',
          date: baseDate,
          dailyVolume: 500.0,
        ),
      );

      final total = await dataSource.getTotalVolumeForMuscle('mid-chest');
      expect(total, closeTo(0.0, 0.001));
    });

    test('startDate bound is inclusive', () async {
      // baseDate = 2026-04-07, yesterday = 2026-04-06
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-base',
          ownerUserId: userA,
          date: baseDate,
          dailyVolume: 800.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-yest',
          ownerUserId: userA,
          date: yesterday,
          dailyVolume: 200.0,
        ),
      );

      // startDate = baseDate → only the baseDate row is included
      final total = await dataSource.getTotalVolumeForMuscle(
        'mid-chest',
        startDate: baseDate,
      );
      expect(total, closeTo(800.0, 0.001));
    });

    test('endDate bound is inclusive', () async {
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-base',
          ownerUserId: userA,
          date: baseDate,
          dailyVolume: 800.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-yest',
          ownerUserId: userA,
          date: yesterday,
          dailyVolume: 200.0,
        ),
      );

      // endDate = yesterday → only the yesterday row is included
      final total = await dataSource.getTotalVolumeForMuscle(
        'mid-chest',
        endDate: yesterday,
      );
      expect(total, closeTo(200.0, 0.001));
    });

    test('windowed query sums only rows within [startDate, endDate]', () async {
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-base',
          ownerUserId: userA,
          date: baseDate,
          dailyVolume: 800.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-yest',
          ownerUserId: userA,
          date: yesterday,
          dailyVolume: 200.0,
        ),
      );
      await dataSource.upsertStimulus(
        buildStimulusWithVolume(
          id: 'a-old',
          ownerUserId: userA,
          date: twoDaysAgo,
          dailyVolume: 100.0,
        ),
      );

      // Window [yesterday, baseDate] → 200 + 800 = 1000
      final total = await dataSource.getTotalVolumeForMuscle(
        'mid-chest',
        startDate: yesterday,
        endDate: baseDate,
      );
      expect(total, closeTo(1000.0, 0.001));
    });
  });
}
