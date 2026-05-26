import 'package:equatable/equatable.dart';

import 'voice_settings.dart';

enum WeekStartDay { monday, sunday }

enum WeightUnit { kilograms, pounds }

class AppSettings extends Equatable {
  final bool notificationsEnabled;
  final WeekStartDay weekStartDay;
  final WeightUnit weightUnit;

  /// Stores collapsed/expanded state keyed by stable section IDs.
  /// Missing keys fall back to each section's `initiallyExpanded` default.
  final Map<String, bool> uiExpansionState;

  /// Voice-bot preferences. Always present; defaults to the master-spec
  /// values when no rows exist in `app_metadata`.
  final VoiceSettings voiceSettings;

  const AppSettings({
    required this.notificationsEnabled,
    required this.weekStartDay,
    required this.weightUnit,
    this.uiExpansionState = const <String, bool>{},
    this.voiceSettings = const VoiceSettings.defaults(),
  });

  const AppSettings.defaults()
    : notificationsEnabled = true,
      weekStartDay = WeekStartDay.monday,
      weightUnit = WeightUnit.kilograms,
      uiExpansionState = const <String, bool>{},
      voiceSettings = const VoiceSettings.defaults();

  AppSettings copyWith({
    bool? notificationsEnabled,
    WeekStartDay? weekStartDay,
    WeightUnit? weightUnit,
    Map<String, bool>? uiExpansionState,
    VoiceSettings? voiceSettings,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      weightUnit: weightUnit ?? this.weightUnit,
      uiExpansionState: uiExpansionState ?? this.uiExpansionState,
      voiceSettings: voiceSettings ?? this.voiceSettings,
    );
  }

  String get weekStartDayLabel {
    switch (weekStartDay) {
      case WeekStartDay.monday:
        return 'Monday';
      case WeekStartDay.sunday:
        return 'Sunday';
    }
  }

  String get weightUnitLabel {
    switch (weightUnit) {
      case WeightUnit.kilograms:
        return 'Kilograms (kg)';
      case WeightUnit.pounds:
        return 'Pounds (lb)';
    }
  }

  @override
  List<Object?> get props => [
    notificationsEnabled,
    weekStartDay,
    weightUnit,
    uiExpansionState,
    voiceSettings,
  ];
}
