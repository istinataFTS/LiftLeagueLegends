import 'package:fitness_tracker/core/enums/sync_trigger.dart';
import 'package:fitness_tracker/core/sync/post_sync_hook.dart';
import 'package:fitness_tracker/core/sync/sync_orchestrator.dart';
import 'package:fitness_tracker/core/time/clock.dart';
import 'package:fitness_tracker/core/time/system_clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_remote_datasource.dart';
import 'fake_clock.dart';
import 'home_integration_harness.dart';
import 'in_memory_db_harness.dart';
import 'recording_post_sync_hook.dart';
import 'recording_sync_feature.dart';
import 'recording_sync_orchestrator.dart';
import 'test_env.dart';

/// Phase 6.1 sanity suite.
///
/// These tests assert that the integration-test harness itself behaves
/// the way later phases will rely on. They are intentionally coarse: if
/// one of these fails, every downstream integration test is suspect.
void main() {
  group('SystemClock', () {
    test('returns a DateTime close to wall clock now()', () {
      const Clock clock = SystemClock();
      final DateTime before = DateTime.now();
      final DateTime reading = clock.now();
      final DateTime after = DateTime.now();

      expect(
        reading.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
        reason: 'reading must not predate the call',
      );
      expect(
        reading.isAfter(after.add(const Duration(seconds: 1))),
        isFalse,
        reason: 'reading must not be in the future relative to after-call',
      );
    });
  });

  group('FakeClock', () {
    test('starts at the initial timestamp', () {
      final FakeClock clock = FakeClock(TestEnv.referenceNow);
      expect(clock.now(), equals(TestEnv.referenceNow));
    });

    test('advance() moves time forward deterministically', () {
      final FakeClock clock = FakeClock(TestEnv.referenceNow);
      clock.advance(const Duration(hours: 3));
      expect(
        clock.now(),
        equals(TestEnv.referenceNow.add(const Duration(hours: 3))),
      );
    });

    test('advance() rejects negative durations', () {
      final FakeClock clock = FakeClock(TestEnv.referenceNow);
      expect(
        () => clock.advance(const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('setTo() refuses to rewind', () {
      final FakeClock clock = FakeClock(TestEnv.referenceNow);
      expect(
        () =>
            clock.setTo(TestEnv.referenceNow.subtract(const Duration(days: 1))),
        throwsArgumentError,
      );
    });
  });

  group('InMemoryDbHarness', () {
    test('opens a populated schema with production tables', () async {
      final InMemoryDbHarness db = await InMemoryDbHarness.open();
      addTearDown(db.close);

      final result = await db.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = result.map((row) => row['name'] as String).toSet();

      // Spot-check a handful of tables that later phases will hit.
      expect(names, contains('exercises'));
      expect(names, contains('workout_sets'));
      expect(names, contains('muscle_stimulus'));
    });

    test('each open() yields an isolated database', () async {
      final InMemoryDbHarness a = await InMemoryDbHarness.open();
      addTearDown(a.close);
      final InMemoryDbHarness b = await InMemoryDbHarness.open();
      addTearDown(b.close);

      expect(identical(a.database, b.database), isFalse);
    });
  });

  group('RecordingSyncFeature / RecordingPostSyncHook', () {
    test(
      'shared callLog captures push, pull, and hook invocations in order',
      () async {
        final List<String> log = <String>[];

        final feature = RecordingSyncFeature(
          name: 'exercises',
          callLog: log,
        ).toSyncFeature();

        final hook = RecordingPostSyncHook(
          name: 'muscleFactorHeal',
          triggeringFeatures: const <String>{'exercises'},
          callLog: log,
        );

        await feature.pullRemoteChanges('user-a', null);
        await feature.syncPendingChanges();
        await hook.run(
          const PostSyncContext(
            userId: 'user-a',
            pulledFeatures: <String>{'exercises'},
            trigger: SyncTrigger.manualRefresh,
          ),
        );

        expect(
          log,
          equals(<String>[
            'exercises:pull',
            'exercises:push',
            'muscleFactorHeal:run',
          ]),
        );
      },
    );
  });

  group('RecordingSyncOrchestrator', () {
    test('returns queued results in order and logs triggers', () async {
      final orch = RecordingSyncOrchestrator();
      orch.enqueueCompleted(SyncTrigger.initialSignIn);
      orch.enqueueCompleted(SyncTrigger.manualRefresh);

      final a = await orch.run(SyncTrigger.initialSignIn);
      final b = await orch.run(SyncTrigger.manualRefresh);

      expect(a.status, SyncRunStatus.completed);
      expect(b.status, SyncRunStatus.completed);
      expect(
        orch.triggers,
        equals(<SyncTrigger>[
          SyncTrigger.initialSignIn,
          SyncTrigger.manualRefresh,
        ]),
      );
    });

    test('returns a "no canned result" skipped when queue is empty', () async {
      final orch = RecordingSyncOrchestrator();
      final result = await orch.run(SyncTrigger.manualRefresh);
      expect(result.status, SyncRunStatus.skipped);
      expect(result.message, contains('no canned result'));
    });
  });

  group('FakeAuthRemoteDataSource', () {
    test('signInWithEmail records the call and returns a user', () async {
      final auth = FakeAuthRemoteDataSource();
      final user = await auth.signInWithEmail(email: 'a@b.c', password: 'pw');
      expect(user.email, 'a@b.c');
      expect(auth.callLog, equals(<String>['signInWithEmail']));
    });

    test('signInError is thrown when configured', () async {
      final auth = FakeAuthRemoteDataSource(signInError: StateError('boom'));
      expect(
        () => auth.signInWithEmail(email: 'a@b.c', password: 'pw'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('HomeIntegrationHarness', () {
    test(
      'create() wires the pieces together and dispose() cleans up',
      () async {
        final harness = await HomeIntegrationHarness.create();
        expect(harness.clock.now(), equals(TestEnv.referenceNow));
        expect(harness.auth.isConfigured, isTrue);
        expect(harness.db.database.isOpen, isTrue);

        await harness.dispose();
        expect(harness.db.database.isOpen, isFalse);
      },
    );
  });
}
