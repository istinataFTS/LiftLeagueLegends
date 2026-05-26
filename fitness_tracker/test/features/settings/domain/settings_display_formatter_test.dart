import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/settings/domain/settings_display_formatter.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';

void main() {
  group('SettingsDisplayFormatter', () {
    group('weekPreview', () {
      // Default sample date is DateTime(2026, 3, 19) — a Thursday.
      test(
        'formats week range with monday start using default sample date',
        () {
          // Mon Mar 16 – Sun Mar 22
          expect(
            SettingsDisplayFormatter.weekPreview(WeekStartDay.monday),
            'Week preview: Mar 16 - Mar 22',
          );
        },
      );

      test(
        'formats week range with sunday start using default sample date',
        () {
          // Sun Mar 15 – Sat Mar 21
          expect(
            SettingsDisplayFormatter.weekPreview(WeekStartDay.sunday),
            'Week preview: Mar 15 - Mar 21',
          );
        },
      );

      test('formats week range with custom sample date', () {
        // Wednesday 2026-03-25, monday start → Mon Mar 23 – Sun Mar 29
        expect(
          SettingsDisplayFormatter.weekPreview(
            WeekStartDay.monday,
            sampleDate: DateTime(2026, 3, 25),
          ),
          'Week preview: Mar 23 - Mar 29',
        );
      });
    });

    group('weightPreview', () {
      test('formats sample weight in kilograms', () {
        // 82.5 kg stored → 82.5 kg displayed → "82.5 kg"
        expect(
          SettingsDisplayFormatter.weightPreview(WeightUnit.kilograms),
          'Display preview: 82.5 kg',
        );
      });

      test('formats sample weight in pounds', () {
        // 82.5 kg → 82.5 × 2.2046226218 ≈ 181.88 → formatNumber → "181.9"
        expect(
          SettingsDisplayFormatter.weightPreview(WeightUnit.pounds),
          'Display preview: 181.9 lbs',
        );
      });
    });

    group('saveErrorMessage', () {
      test('interpolates error message into failure string', () {
        expect(
          SettingsDisplayFormatter.saveErrorMessage('Network error'),
          'Failed to save settings: Network error',
        );
      });

      test('interpolates empty error message', () {
        expect(
          SettingsDisplayFormatter.saveErrorMessage(''),
          'Failed to save settings: ',
        );
      });
    });

    group('constants', () {
      test('saveSuccessMessage has expected value', () {
        expect(SettingsDisplayFormatter.saveSuccessMessage, 'Settings saved');
      });

      test('infoMessage mentions local storage and Supabase migration', () {
        expect(
          SettingsDisplayFormatter.infoMessage,
          'These settings are stored locally today and are safe to keep when the app moves to Supabase-backed accounts later.',
        );
      });

      test('storageModeSubtitle has expected value', () {
        expect(
          SettingsDisplayFormatter.storageModeSubtitle,
          'Local device settings now, account sync later',
        );
      });
    });
  });
}
