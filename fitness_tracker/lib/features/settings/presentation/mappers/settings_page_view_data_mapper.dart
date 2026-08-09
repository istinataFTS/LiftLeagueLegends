import '../../../../core/constants/app_info.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../settings/application/app_settings_cubit.dart';
import '../../domain/settings_display_formatter.dart';
import '../models/settings_page_view_data.dart';

class SettingsPageViewDataMapper {
  const SettingsPageViewDataMapper._();

  static SettingsPageViewData map(AppSettingsState state, {String? username}) {
    final AppSettings settings = state.settings;
    final bool hasUsername = username != null && username.isNotEmpty;

    return SettingsPageViewData(
      infoMessage: SettingsDisplayFormatter.infoMessage,
      generalSectionTitle: 'General',
      accountSectionVisible: hasUsername,
      accountSectionTitle: 'Account',
      usernameTitle: 'Username',
      usernameValue: hasUsername ? '@$username' : '',
      usernameSubtitle: 'Your unique handle — visible to other users',
      aboutSectionTitle: 'About',
      deferredSectionTitle: 'Deferred Until Auth / Cloud',
      notificationsTitle: 'Notifications',
      notificationsSubtitle: 'Workout reminders and local alerts',
      notificationsEnabled: settings.notificationsEnabled,
      weekStartTitle: 'Week Start Day',
      weekStartSubtitle: settings.weekStartDayLabel,
      weekStartPreview: SettingsDisplayFormatter.weekPreview(
        settings.weekStartDay,
      ),
      weekStartOptions: <SettingsSelectionOptionViewData<WeekStartDay>>[
        SettingsSelectionOptionViewData<WeekStartDay>(
          value: WeekStartDay.monday,
          title: 'Monday',
          selected: settings.weekStartDay == WeekStartDay.monday,
        ),
        SettingsSelectionOptionViewData<WeekStartDay>(
          value: WeekStartDay.sunday,
          title: 'Sunday',
          selected: settings.weekStartDay == WeekStartDay.sunday,
        ),
      ],
      weightUnitTitle: 'Weight Units',
      weightUnitSubtitle: settings.weightUnitLabel,
      weightUnitPreview: SettingsDisplayFormatter.weightPreview(
        settings.weightUnit,
      ),
      weightUnitOptions: <SettingsSelectionOptionViewData<WeightUnit>>[
        SettingsSelectionOptionViewData<WeightUnit>(
          value: WeightUnit.kilograms,
          title: 'Kilograms (kg)',
          selected: settings.weightUnit == WeightUnit.kilograms,
        ),
        SettingsSelectionOptionViewData<WeightUnit>(
          value: WeightUnit.pounds,
          title: 'Pounds (lb)',
          selected: settings.weightUnit == WeightUnit.pounds,
        ),
      ],
      appVersionTitle: 'App Version',
      appVersionSubtitle: AppInfo.versionLabel,
      storageModeTitle: 'Storage Mode',
      storageModeSubtitle: SettingsDisplayFormatter.storageModeSubtitle,
      deferredItems: const <DeferredSettingsItemViewData>[
        DeferredSettingsItemViewData(
          title: 'Theme',
          subtitle: 'Hold for the wider app-shell theming pass',
        ),
        DeferredSettingsItemViewData(
          title: 'Backup & Restore',
          subtitle: 'Best added after the Supabase sync path is in place',
        ),
        DeferredSettingsItemViewData(
          title: 'Terms & Privacy',
          subtitle: 'Needs final hosted documents / URLs',
        ),
        DeferredSettingsItemViewData(
          title: 'Report a Bug',
          subtitle: 'Needs a connected support destination',
        ),
      ],
      isLoading: state.isLoading && !state.hasLoaded,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
    );
  }
}
