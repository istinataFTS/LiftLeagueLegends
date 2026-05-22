import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/app_metadata_local_datasource.dart';
import 'package:fitness_tracker/data/repositories/app_settings_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppMetadataLocalDataSource extends Mock
    implements AppMetadataLocalDataSource {}

void main() {
  late MockAppMetadataLocalDataSource mockDataSource;
  late AppSettingsRepositoryImpl repository;

  setUp(() {
    mockDataSource = MockAppMetadataLocalDataSource();
    repository = AppSettingsRepositoryImpl(localDataSource: mockDataSource);

    // General fallbacks so that fields added after this test was written
    // (e.g. voice settings, uiExpansionState) do not cause MissingStubError
    // when a specific test only stubs the keys it cares about.
    when(() => mockDataSource.readString(any())).thenAnswer((_) async => null);
    when(() => mockDataSource.readBool(any())).thenAnswer((_) async => null);
    when(
      () => mockDataSource.readJsonObject(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockDataSource.writeString(any(), any()),
    ).thenAnswer((_) async {});
    when(() => mockDataSource.writeBool(any(), any())).thenAnswer((_) async {});
    when(
      () => mockDataSource.writeJsonObject(any(), any()),
    ).thenAnswer((_) async {});
  });

  group('AppSettingsRepositoryImpl', () {
    group('getSettings', () {
      test(
        'returns defaults when datasource returns null for all keys',
        () async {
          when(
            () => mockDataSource.readBool('settings.notifications_enabled'),
          ).thenAnswer((_) async => null);
          when(
            () => mockDataSource.readString('settings.week_start_day'),
          ).thenAnswer((_) async => null);
          when(
            () => mockDataSource.readString('settings.weight_unit'),
          ).thenAnswer((_) async => null);

          final result = await repository.getSettings();

          expect(result.isRight(), isTrue);
          expect(
            (result as Right).value,
            const AppSettings(
              notificationsEnabled: true,
              weekStartDay: WeekStartDay.monday,
              weightUnit: WeightUnit.kilograms,
            ),
          );
        },
      );

      test('returns parsed settings when stored values are present', () async {
        when(
          () => mockDataSource.readBool('settings.notifications_enabled'),
        ).thenAnswer((_) async => false);
        when(
          () => mockDataSource.readString('settings.week_start_day'),
        ).thenAnswer((_) async => 'sunday');
        when(
          () => mockDataSource.readString('settings.weight_unit'),
        ).thenAnswer((_) async => 'pounds');

        final result = await repository.getSettings();

        expect(result.isRight(), isTrue);
        expect(
          (result as Right).value,
          const AppSettings(
            notificationsEnabled: false,
            weekStartDay: WeekStartDay.sunday,
            weightUnit: WeightUnit.pounds,
          ),
        );
      });

      test('weekStartDay defaults to monday for unrecognised value', () async {
        when(
          () => mockDataSource.readBool('settings.notifications_enabled'),
        ).thenAnswer((_) async => true);
        when(
          () => mockDataSource.readString('settings.week_start_day'),
        ).thenAnswer((_) async => 'wednesday');
        when(
          () => mockDataSource.readString('settings.weight_unit'),
        ).thenAnswer((_) async => null);

        final result = await repository.getSettings();

        expect(result.isRight(), isTrue);
        expect(
          ((result as Right).value as AppSettings).weekStartDay,
          WeekStartDay.monday,
        );
      });

      test('weightUnit defaults to kilograms for unrecognised value', () async {
        when(
          () => mockDataSource.readBool('settings.notifications_enabled'),
        ).thenAnswer((_) async => true);
        when(
          () => mockDataSource.readString('settings.week_start_day'),
        ).thenAnswer((_) async => null);
        when(
          () => mockDataSource.readString('settings.weight_unit'),
        ).thenAnswer((_) async => 'stones');

        final result = await repository.getSettings();

        expect(result.isRight(), isTrue);
        expect(
          ((result as Right).value as AppSettings).weightUnit,
          WeightUnit.kilograms,
        );
      });

      test('returns DatabaseFailure when datasource throws', () async {
        when(
          () => mockDataSource.readBool('settings.notifications_enabled'),
        ).thenThrow(const CacheDatabaseException('read error'));
        when(
          () => mockDataSource.readString(any()),
        ).thenAnswer((_) async => null);

        final result = await repository.getSettings();

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('saveSettings', () {
      const _settings = AppSettings(
        notificationsEnabled: false,
        weekStartDay: WeekStartDay.sunday,
        weightUnit: WeightUnit.pounds,
      );

      test('persists each field under the correct key', () async {
        when(
          () =>
              mockDataSource.writeBool('settings.notifications_enabled', false),
        ).thenAnswer((_) async {});
        when(
          () => mockDataSource.writeString('settings.week_start_day', 'sunday'),
        ).thenAnswer((_) async {});
        when(
          () => mockDataSource.writeString('settings.weight_unit', 'pounds'),
        ).thenAnswer((_) async {});

        final result = await repository.saveSettings(_settings);

        expect(result.isRight(), isTrue);
        verify(
          () =>
              mockDataSource.writeBool('settings.notifications_enabled', false),
        ).called(1);
        verify(
          () => mockDataSource.writeString('settings.week_start_day', 'sunday'),
        ).called(1);
        verify(
          () => mockDataSource.writeString('settings.weight_unit', 'pounds'),
        ).called(1);
      });

      test('returns DatabaseFailure when datasource throws', () async {
        when(
          () => mockDataSource.writeBool(any(), any()),
        ).thenThrow(const CacheDatabaseException('write error'));
        when(
          () => mockDataSource.writeString(any(), any()),
        ).thenAnswer((_) async {});

        final result = await repository.saveSettings(_settings);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('watchSettings', () {
      const _initial = AppSettings(
        notificationsEnabled: true,
        weekStartDay: WeekStartDay.monday,
        weightUnit: WeightUnit.kilograms,
      );
      const _saved = AppSettings(
        notificationsEnabled: false,
        weekStartDay: WeekStartDay.sunday,
        weightUnit: WeightUnit.pounds,
      );

      test('emits nothing to a subscriber before any read or save', () async {
        // No getSettings, no saveSettings — the broadcast cache is empty
        // and `Stream.multi` has nothing to replay.
        final events = <AppSettings>[];
        final sub = repository.watchSettings().listen(events.add);
        // Yield once so any pending microtask emit would have surfaced.
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);
        await sub.cancel();
      });

      test(
        'replays the last cached value to a new subscriber after getSettings',
        () async {
          // Seed the cache via getSettings.
          await repository.getSettings();

          final events = <AppSettings>[];
          final sub = repository.watchSettings().listen(events.add);
          await Future<void>.delayed(Duration.zero);
          // The seeded value matches the datasource's defaults-only path.
          expect(events, hasLength(1));
          expect(events.single, _initial);
          await sub.cancel();
        },
      );

      test(
        'emits to all current subscribers after a successful saveSettings',
        () async {
          await repository.getSettings();

          final eventsA = <AppSettings>[];
          final eventsB = <AppSettings>[];
          final subA = repository.watchSettings().listen(eventsA.add);
          final subB = repository.watchSettings().listen(eventsB.add);
          // Drain the replay-on-subscribe event.
          await Future<void>.delayed(Duration.zero);
          eventsA.clear();
          eventsB.clear();

          final result = await repository.saveSettings(_saved);
          await Future<void>.delayed(Duration.zero);

          expect(result.isRight(), isTrue);
          expect(eventsA, equals(<AppSettings>[_saved]));
          expect(eventsB, equals(<AppSettings>[_saved]));

          await subA.cancel();
          await subB.cancel();
        },
      );

      test('does NOT emit when saveSettings fails', () async {
        await repository.getSettings();

        final events = <AppSettings>[];
        final sub = repository.watchSettings().listen(events.add);
        await Future<void>.delayed(Duration.zero);
        events.clear();

        when(
          () => mockDataSource.writeBool(any(), any()),
        ).thenThrow(const CacheDatabaseException('write error'));

        final result = await repository.saveSettings(_saved);
        await Future<void>.delayed(Duration.zero);

        expect(result.isLeft(), isTrue);
        expect(events, isEmpty);
        await sub.cancel();
      });

      test('cache reflects the most recently saved settings', () async {
        // No prior getSettings — the cache is empty. After a successful
        // save, a new subscriber should still get the saved value on
        // subscribe.
        await repository.saveSettings(_saved);

        final events = <AppSettings>[];
        final sub = repository.watchSettings().listen(events.add);
        await Future<void>.delayed(Duration.zero);

        expect(events, equals(<AppSettings>[_saved]));
        await sub.cancel();
      });
    });
  });
}
