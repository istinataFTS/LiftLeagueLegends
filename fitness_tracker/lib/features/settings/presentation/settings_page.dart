import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/validation/username_validator.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/voice_settings.dart';
// convention-checker:allow=cross-feature-presentation-import reason=settings observes ProfileCubit (app-level singleton) for username display; data-observation pattern, not navigation
import '../../../features/profile/application/profile_cubit.dart';
import '../application/app_settings_cubit.dart';
import '../domain/settings_display_formatter.dart';
import 'mappers/settings_page_view_data_mapper.dart';
import 'models/settings_page_view_data.dart';
import 'settings_page_keys.dart';
import 'widgets/settings_content.dart';
import 'widgets/settings_option_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const Key loadingIndicatorKey = SettingsPageKeys.loadingIndicatorKey;
  static const Key refreshListKey = SettingsPageKeys.refreshListKey;
  static const Key notificationsSwitchKey =
      SettingsPageKeys.notificationsSwitchKey;
  static const Key weekStartTileKey = SettingsPageKeys.weekStartTileKey;
  static const Key weightUnitTileKey = SettingsPageKeys.weightUnitTileKey;
  static const Key savingIndicatorKey = SettingsPageKeys.savingIndicatorKey;
  static const Key errorBannerKey = SettingsPageKeys.errorBannerKey;
  static const Key usernameTileKey = SettingsPageKeys.usernameTileKey;
  static const Key usernameDialogFieldKey =
      SettingsPageKeys.usernameDialogFieldKey;
  static const Key usernameDialogSaveKey =
      SettingsPageKeys.usernameDialogSaveKey;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<AppSettingsCubit>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppSettingsCubit, AppSettingsState>(
      listenWhen: (AppSettingsState previous, AppSettingsState current) =>
          previous.errorMessage != current.errorMessage,
      listener: (BuildContext context, AppSettingsState state) {
        final String? errorMessage = state.errorMessage;
        if (errorMessage == null || errorMessage.isEmpty) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              SettingsDisplayFormatter.saveErrorMessage(errorMessage),
            ),
          ),
        );
        context.read<AppSettingsCubit>().clearError();
      },
      builder: (BuildContext context, AppSettingsState state) {
        // Voice settings live inside [AppSettings]; reading them off the
        // same cubit avoids depending on `VoiceSettingsCubit` here. Both
        // cubits subscribe to `AppSettingsRepository.watchSettings()`,
        // so the values stay in sync.
        final VoiceSettings voiceSettings = state.settings.voiceSettings;
        final ProfileState profileState = context.watch<ProfileCubit>().state;
        final String? username = profileState.session != null
            ? profileState.userProfile?.username
            : null;
        final SettingsPageViewData viewData = SettingsPageViewDataMapper.map(
          state,
          voiceSettings: voiceSettings,
          username: username,
        );

        return Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          appBar: AppBar(title: const Text('Settings')),
          body: SettingsContent(
            viewData: viewData,
            onRefresh: () => context.read<AppSettingsCubit>().refreshSettings(),
            onNotificationsChanged: (bool value) async {
              await _saveWithFeedback(
                context,
                operation: () {
                  return context
                      .read<AppSettingsCubit>()
                      .setNotificationsEnabled(value);
                },
              );
            },
            onWeekStartTapped: state.isSaving
                ? () {}
                : () => _selectWeekStartDay(context, viewData, state.settings),
            onWeightUnitTapped: state.isSaving
                ? () {}
                : () => _selectWeightUnit(context, viewData, state.settings),
            onOpenVoiceSettings: () => _openVoiceSettings(context),
            onUsernameTapped: profileState.isLoading
                ? () {}
                : () => _editUsername(context, username ?? ''),
          ),
        );
      },
    );
  }

  void _openVoiceSettings(BuildContext context) {
    // VoiceSettingsCubit is provided at the auth-session shell level,
    // so pushed routes resolve it via `context.read` automatically —
    // no nested BlocProvider needed here.
    Navigator.of(context).pushNamed(AppRoutes.voiceSettings);
  }

  Future<void> _editUsername(
    BuildContext context,
    String currentUsername,
  ) async {
    final ProfileCubit profileCubit = context.read<ProfileCubit>();

    final String? newUsername = await showDialog<String>(
      context: context,
      builder: (_) => _UsernameEditDialog(initialValue: currentUsername),
    );

    if (newUsername == null || !context.mounted) {
      return;
    }

    final bool success = await profileCubit.updateUsername(newUsername);

    if (!context.mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username updated.')));
      return;
    }

    final String? error = profileCubit.state.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      profileCubit.clearError();
    }
  }

  Future<void> _selectWeekStartDay(
    BuildContext context,
    SettingsPageViewData viewData,
    AppSettings settings,
  ) async {
    final AppSettingsCubit cubit = context.read<AppSettingsCubit>();
    final WeekStartDay? selected = await showModalBottomSheet<WeekStartDay>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (BuildContext context) {
        return SettingsOptionSheet<WeekStartDay>(
          options: viewData.weekStartOptions
              .map(
                (SettingsSelectionOptionViewData<WeekStartDay> option) =>
                    SettingsOption<WeekStartDay>(
                      value: option.value,
                      title: option.title,
                      selected: option.selected,
                    ),
              )
              .toList(growable: false),
        );
      },
    );

    if (selected == null || selected == settings.weekStartDay) {
      return;
    }

    if (!context.mounted) return;
    await _saveWithFeedback(
      context,
      operation: () => cubit.setWeekStartDay(selected),
    );
  }

  Future<void> _selectWeightUnit(
    BuildContext context,
    SettingsPageViewData viewData,
    AppSettings settings,
  ) async {
    final AppSettingsCubit cubit = context.read<AppSettingsCubit>();
    final WeightUnit? selected = await showModalBottomSheet<WeightUnit>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (BuildContext context) {
        return SettingsOptionSheet<WeightUnit>(
          options: viewData.weightUnitOptions
              .map(
                (SettingsSelectionOptionViewData<WeightUnit> option) =>
                    SettingsOption<WeightUnit>(
                      value: option.value,
                      title: option.title,
                      selected: option.selected,
                    ),
              )
              .toList(growable: false),
        );
      },
    );

    if (selected == null || selected == settings.weightUnit) {
      return;
    }

    if (!context.mounted) return;
    await _saveWithFeedback(
      context,
      operation: () => cubit.setWeightUnit(selected),
    );
  }

  Future<void> _saveWithFeedback(
    BuildContext context, {
    required Future<bool> Function() operation,
  }) async {
    final bool success = await operation();

    if (!success || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(SettingsDisplayFormatter.saveSuccessMessage),
      ),
    );
  }
}

/// Modal username editor. Validates inline via [UsernameValidator] before
/// allowing submission, then pops the trimmed value back to the caller.
class _UsernameEditDialog extends StatefulWidget {
  const _UsernameEditDialog({required this.initialValue});

  /// Current handle without the leading `@`.
  final String initialValue;

  @override
  State<_UsernameEditDialog> createState() => _UsernameEditDialogState();
}

class _UsernameEditDialogState extends State<_UsernameEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    final String? validationError = UsernameValidator.validate(value);

    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      title: const Text('Change username'),
      content: TextField(
        key: SettingsPageKeys.usernameDialogFieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: UsernameValidator.maxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          prefixText: '@',
          labelText: 'Username',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() => _errorText = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: SettingsPageKeys.usernameDialogSaveKey,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
