import '../../../core/utils/week_range_label_formatter.dart';
import '../../../core/utils/weight_unit_utils.dart';
import '../../../domain/entities/app_settings.dart';

class SettingsDisplayFormatter {
  const SettingsDisplayFormatter._();

  static final DateTime _defaultSampleDate = DateTime(2026, 3, 19);
  static const double _defaultSampleWeightKg = 82.5;

  static String weekPreview(WeekStartDay weekStartDay, {DateTime? sampleDate}) {
    final String range = WeekRangeLabelFormatter.formatForDate(
      sampleDate ?? _defaultSampleDate,
      weekStartDay: weekStartDay,
    );

    return 'Week preview: $range';
  }

  static String weightPreview(
    WeightUnit weightUnit, {
    double sampleWeightKg = _defaultSampleWeightKg,
  }) {
    final String formatted = WeightUnitUtils.formatForDisplay(
      sampleWeightKg,
      weightUnit,
    );

    return 'Display preview: $formatted';
  }

  static String saveErrorMessage(String errorMessage) {
    return 'Failed to save settings: $errorMessage';
  }

  static const String saveSuccessMessage = 'Settings saved';

  static const String infoMessage =
      'These settings are stored locally today and are safe to keep when the app moves to Supabase-backed accounts later.';

  static const String storageModeSubtitle =
      'Local device settings now, account sync later';
}
