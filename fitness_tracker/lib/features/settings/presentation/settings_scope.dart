import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/app_settings.dart';
import '../application/app_settings_cubit.dart';

class SettingsScope extends StatelessWidget {
  const SettingsScope({required this.child, super.key});

  final Widget child;

  static AppSettings of(BuildContext context) {
    final _InheritedSettingsScope? scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedSettingsScope>();

    assert(
      scope != null,
      'SettingsScope.of() called with a context that does not contain SettingsScope.',
    );

    return scope!.settings;
  }

  static AppSettings? maybeOf(BuildContext context) {
    final _InheritedSettingsScope? scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedSettingsScope>();

    return scope?.settings;
  }

  static WeightUnit weightUnitOf(BuildContext context) {
    return of(context).weightUnit;
  }

  static WeekStartDay weekStartDayOf(BuildContext context) {
    return of(context).weekStartDay;
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppSettingsCubit, AppSettingsState, AppSettings>(
      selector: (AppSettingsState state) => state.settings,
      builder: (BuildContext context, AppSettings settings) {
        return _InheritedSettingsScope(settings: settings, child: child);
      },
    );
  }
}

class _InheritedSettingsScope extends InheritedWidget {
  const _InheritedSettingsScope({required this.settings, required super.child});

  final AppSettings settings;

  @override
  bool updateShouldNotify(_InheritedSettingsScope oldWidget) {
    return oldWidget.settings != settings;
  }
}
