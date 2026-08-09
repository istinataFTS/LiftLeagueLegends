import 'package:equatable/equatable.dart';

import '../../../../domain/entities/app_settings.dart';

class SettingsPageViewData extends Equatable {
  const SettingsPageViewData({
    required this.infoMessage,
    required this.generalSectionTitle,
    required this.accountSectionVisible,
    required this.accountSectionTitle,
    required this.usernameTitle,
    required this.usernameValue,
    required this.usernameSubtitle,
    required this.aboutSectionTitle,
    required this.deferredSectionTitle,
    required this.notificationsTitle,
    required this.notificationsSubtitle,
    required this.notificationsEnabled,
    required this.weekStartTitle,
    required this.weekStartSubtitle,
    required this.weekStartPreview,
    required this.weekStartOptions,
    required this.weightUnitTitle,
    required this.weightUnitSubtitle,
    required this.weightUnitPreview,
    required this.weightUnitOptions,
    required this.appVersionTitle,
    required this.appVersionSubtitle,
    required this.storageModeTitle,
    required this.storageModeSubtitle,
    required this.deferredItems,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  final String infoMessage;
  final String generalSectionTitle;

  /// Whether the Account section (username editing) is shown. True only for
  /// an authenticated user with a loaded profile.
  final bool accountSectionVisible;
  final String accountSectionTitle;
  final String usernameTitle;

  /// Current handle rendered as `@handle`; empty when not authenticated.
  final String usernameValue;
  final String usernameSubtitle;
  final String aboutSectionTitle;
  final String deferredSectionTitle;
  final String notificationsTitle;
  final String notificationsSubtitle;
  final bool notificationsEnabled;
  final String weekStartTitle;
  final String weekStartSubtitle;
  final String weekStartPreview;
  final List<SettingsSelectionOptionViewData<WeekStartDay>> weekStartOptions;
  final String weightUnitTitle;
  final String weightUnitSubtitle;
  final String weightUnitPreview;
  final List<SettingsSelectionOptionViewData<WeightUnit>> weightUnitOptions;
  final String appVersionTitle;
  final String appVersionSubtitle;
  final String storageModeTitle;
  final String storageModeSubtitle;
  final List<DeferredSettingsItemViewData> deferredItems;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  @override
  List<Object?> get props => <Object?>[
    infoMessage,
    generalSectionTitle,
    accountSectionVisible,
    accountSectionTitle,
    usernameTitle,
    usernameValue,
    usernameSubtitle,
    aboutSectionTitle,
    deferredSectionTitle,
    notificationsTitle,
    notificationsSubtitle,
    notificationsEnabled,
    weekStartTitle,
    weekStartSubtitle,
    weekStartPreview,
    weekStartOptions,
    weightUnitTitle,
    weightUnitSubtitle,
    weightUnitPreview,
    weightUnitOptions,
    appVersionTitle,
    appVersionSubtitle,
    storageModeTitle,
    storageModeSubtitle,
    deferredItems,
    isLoading,
    isSaving,
    errorMessage,
  ];
}

class SettingsSelectionOptionViewData<T> extends Equatable {
  const SettingsSelectionOptionViewData({
    required this.value,
    required this.title,
    required this.selected,
  });

  final T value;
  final String title;
  final bool selected;

  @override
  List<Object?> get props => <Object?>[value, title, selected];
}

class DeferredSettingsItemViewData extends Equatable {
  const DeferredSettingsItemViewData({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  List<Object?> get props => <Object?>[title, subtitle];
}
