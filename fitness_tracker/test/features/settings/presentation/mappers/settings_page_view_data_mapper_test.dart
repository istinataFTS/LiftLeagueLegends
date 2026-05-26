import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/mappers/settings_page_view_data_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppSettingsState buildState({
    AppSettings settings = const AppSettings.defaults(),
    bool isLoading = false,
    bool isSaving = false,
    bool hasLoaded = true,
    String? errorMessage,
  }) {
    return AppSettingsState(
      settings: settings,
      isLoading: isLoading,
      isSaving: isSaving,
      hasLoaded: hasLoaded,
      errorMessage: errorMessage,
    );
  }

  group('SettingsPageViewDataMapper', () {
    test(
      'maps settings previews and selection options from current settings',
      () {
        final AppSettingsState state = buildState(
          settings: const AppSettings(
            notificationsEnabled: true,
            weekStartDay: WeekStartDay.sunday,
            weightUnit: WeightUnit.pounds,
          ),
        );

        final viewData = SettingsPageViewDataMapper.map(state);

        expect(viewData.notificationsEnabled, isTrue);
        expect(viewData.weekStartSubtitle, 'Sunday');
        expect(viewData.weekStartPreview, 'Week preview: Mar 15 - Mar 21');
        expect(viewData.weightUnitSubtitle, 'Pounds (lb)');
        expect(viewData.weightUnitPreview, 'Display preview: 181.9 lbs');

        expect(viewData.weekStartOptions, hasLength(2));
        expect(
          viewData.weekStartOptions
              .singleWhere((option) => option.value == WeekStartDay.sunday)
              .selected,
          isTrue,
        );
        expect(
          viewData.weekStartOptions
              .singleWhere((option) => option.value == WeekStartDay.monday)
              .selected,
          isFalse,
        );

        expect(viewData.weightUnitOptions, hasLength(2));
        expect(
          viewData.weightUnitOptions
              .singleWhere((option) => option.value == WeightUnit.pounds)
              .selected,
          isTrue,
        );
        expect(
          viewData.weightUnitOptions
              .singleWhere((option) => option.value == WeightUnit.kilograms)
              .selected,
          isFalse,
        );
      },
    );

    test('keeps loading state gated behind hasLoaded', () {
      final AppSettingsState initialLoadingState = buildState(
        isLoading: true,
        hasLoaded: false,
      );

      final AppSettingsState refreshLoadingState = buildState(
        isLoading: true,
        hasLoaded: true,
      );

      final initialViewData = SettingsPageViewDataMapper.map(
        initialLoadingState,
      );
      final refreshViewData = SettingsPageViewDataMapper.map(
        refreshLoadingState,
      );

      expect(initialViewData.isLoading, isTrue);
      expect(refreshViewData.isLoading, isFalse);
    });

    test('passes through saving and error state for feature rendering', () {
      final AppSettingsState state = buildState(
        isSaving: true,
        errorMessage: 'save failed',
      );

      final viewData = SettingsPageViewDataMapper.map(state);

      expect(viewData.isSaving, isTrue);
      expect(viewData.errorMessage, 'save failed');
    });
  });
}
