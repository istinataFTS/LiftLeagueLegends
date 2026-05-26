import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSettingsCubit extends MockCubit<AppSettingsState>
    implements AppSettingsCubit {}

void main() {
  late MockAppSettingsCubit cubit;

  AppSettingsState buildState(AppSettings settings) {
    return AppSettingsState(
      settings: settings,
      isLoading: false,
      isSaving: false,
      hasLoaded: true,
      errorMessage: null,
    );
  }

  Widget buildSubject() {
    return BlocProvider<AppSettingsCubit>.value(
      value: cubit,
      child: const MaterialApp(home: SettingsScope(child: _SettingsProbe())),
    );
  }

  setUp(() {
    cubit = MockAppSettingsCubit();

    final AppSettingsState initialState = buildState(
      const AppSettings(
        notificationsEnabled: true,
        weekStartDay: WeekStartDay.monday,
        weightUnit: WeightUnit.kilograms,
      ),
    );

    when(() => cubit.state).thenReturn(initialState);
    whenListen<AppSettingsState>(
      cubit,
      Stream<AppSettingsState>.fromIterable(<AppSettingsState>[
        initialState,
        buildState(
          const AppSettings(
            notificationsEnabled: true,
            weekStartDay: WeekStartDay.sunday,
            weightUnit: WeightUnit.pounds,
          ),
        ),
      ]),
      initialState: initialState,
    );
  });

  testWidgets('exposes current settings to descendants', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('unit: kilograms'), findsOneWidget);
    expect(find.text('weekStart: monday'), findsOneWidget);
  });

  testWidgets('rebuilds dependents when settings change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('unit: pounds'), findsOneWidget);
    expect(find.text('weekStart: sunday'), findsOneWidget);
  });
}

class _SettingsProbe extends StatelessWidget {
  const _SettingsProbe();

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = SettingsScope.of(context);

    return Scaffold(
      body: Column(
        children: <Widget>[
          Text('unit: ${settings.weightUnit.name}'),
          Text('weekStart: ${settings.weekStartDay.name}'),
        ],
      ),
    );
  }
}
