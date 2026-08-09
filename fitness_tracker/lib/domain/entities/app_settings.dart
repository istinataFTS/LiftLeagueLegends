import 'package:equatable/equatable.dart';

enum WeekStartDay { monday, sunday }

enum WeightUnit { kilograms, pounds }

class AppSettings extends Equatable {
  final bool notificationsEnabled;
  final WeekStartDay weekStartDay;
  final WeightUnit weightUnit;

  /// Stores collapsed/expanded state keyed by stable section IDs.
  /// Missing keys fall back to each section's `initiallyExpanded` default.
  final Map<String, bool> uiExpansionState;

  const AppSettings({
    required this.notificationsEnabled,
    required this.weekStartDay,
    required this.weightUnit,
    this.uiExpansionState = const <String, bool>{},
  });

  const AppSettings.defaults()
    : notificationsEnabled = true,
      weekStartDay = WeekStartDay.monday,
      weightUnit = WeightUnit.kilograms,
      uiExpansionState = const <String, bool>{};

  AppSettings copyWith({
    bool? notificationsEnabled,
    WeekStartDay? weekStartDay,
    WeightUnit? weightUnit,
    Map<String, bool>? uiExpansionState,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      weightUnit: weightUnit ?? this.weightUnit,
      uiExpansionState: uiExpansionState ?? this.uiExpansionState,
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
  ];
}
