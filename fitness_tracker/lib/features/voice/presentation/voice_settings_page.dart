import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/voice_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../domain/entities/voice_settings.dart';
import '../../../domain/services/voice_tts_service.dart';
import '../../../injection/injection_container.dart';
import '../application/voice_settings_cubit.dart';
import 'voice_settings_page_keys.dart';

/// Dedicated Voice Assistant settings page.
///
/// Scoped by a [VoiceSettingsCubit] (factory) provided by the caller —
/// either [VoiceOverlayPage._openSettings] or the Profile → Voice tile.
/// All writes delegate to [AppSettingsCubit] (singleton) so changes are
/// immediately visible to any other open settings surface.
class VoiceSettingsPage extends StatefulWidget {
  const VoiceSettingsPage({super.key});

  @override
  State<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends State<VoiceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: VoiceSettingsPageKeys.pageKey,
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        title: const Text(AppStrings.voiceSettingsPageTitle),
        leading: const BackButton(),
      ),
      body: BlocBuilder<VoiceSettingsCubit, VoiceSettings>(
        builder: (context, settings) {
          final VoiceSettingsCubit cubit = context.read<VoiceSettingsCubit>();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: <Widget>[
              // ── Wake Word ─────────────────────────────────────────────
              const _SectionHeader(AppStrings.voiceWakeWordSectionTitle),
              _WakeWordPicker(
                selected: settings.wakeWordPreset,
                onSelect: cubit.setWakeWordPreset,
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                key: VoiceSettingsPageKeys.wakeWordArmedToggleKey,
                title: const Text(
                  AppStrings.voiceWakeWordArmedTitle,
                  style: TextStyle(color: AppTheme.textLight),
                ),
                subtitle: const Text(
                  AppStrings.voiceWakeWordArmedSubtitle,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
                value: settings.wakeWordArmedInForeground,
                onChanged: cubit.setWakeWordArmedInForeground,
                activeThumbColor: AppTheme.primaryOrange,
              ),

              // ── Behavior ──────────────────────────────────────────────
              const _SectionHeader(AppStrings.voiceBehaviorSectionTitle),
              SwitchListTile(
                key: VoiceSettingsPageKeys.sessionLoggingToggleKey,
                title: const Text(
                  AppStrings.voiceSessionLoggingTitle,
                  style: TextStyle(color: AppTheme.textLight),
                ),
                subtitle: const Text(
                  AppStrings.voiceSessionLoggingSubtitle,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
                value: settings.sessionLoggingEnabled,
                onChanged: cubit.setSessionLoggingEnabled,
                activeThumbColor: AppTheme.primaryOrange,
              ),
              SwitchListTile(
                key: VoiceSettingsPageKeys.workoutModeAutoToggleKey,
                title: const Text(
                  AppStrings.voiceWorkoutModeAutoTitle,
                  style: TextStyle(color: AppTheme.textLight),
                ),
                subtitle: const Text(
                  AppStrings.voiceWorkoutModeAutoSubtitle,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
                value: settings.workoutModeAutoEnable,
                onChanged: cubit.setWorkoutModeAutoEnable,
                activeThumbColor: AppTheme.primaryOrange,
              ),

              // ── Voice Output ──────────────────────────────────────────
              const _SectionHeader(AppStrings.voiceOutputSectionTitle),
              _SliderTile(
                key: VoiceSettingsPageKeys.ttsVolumeSliderKey,
                title: AppStrings.voiceTtsVolumeTitle,
                subtitle: AppStrings.voiceTtsVolumeSubtitle,
                value: settings.ttsVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(settings.ttsVolume * 100).round()}%',
                onChanged: cubit.previewTtsVolume,
                onChangeEnd: cubit.setTtsVolume,
              ),
              _SliderTile(
                key: VoiceSettingsPageKeys.ttsSpeechRateSliderKey,
                title: AppStrings.voiceTtsSpeechRateTitle,
                subtitle: AppStrings.voiceTtsSpeechRateSubtitle,
                value: settings.ttsSpeechRate,
                min: VoiceConstants.minTtsSpeechRate,
                max: VoiceConstants.maxTtsSpeechRate,
                divisions: 6,
                label: '${settings.ttsSpeechRate.toStringAsFixed(1)}×',
                onChanged: cubit.previewTtsSpeechRate,
                onChangeEnd: cubit.setTtsSpeechRate,
              ),

              // ── Daily Budget ──────────────────────────────────────────
              const _SectionHeader(AppStrings.voiceBudgetSectionTitle),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.voiceBudgetResetNote,
                      style: TextStyle(color: AppTheme.textDim, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ── Privacy ───────────────────────────────────────────────
              const _SectionHeader(AppStrings.voicePrivacySectionTitle),
              ListTile(
                key: VoiceSettingsPageKeys.deleteHistoryButtonKey,
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorRed,
                ),
                title: const Text(
                  AppStrings.voiceDeleteHistoryTitle,
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                subtitle: const Text(
                  AppStrings.voiceDeleteHistorySubtitle,
                  style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                ),
                onTap: () => _confirmDeleteHistory(context),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text(
          AppStrings.voiceDeleteHistoryConfirmTitle,
          style: TextStyle(color: AppTheme.textLight),
        ),
        content: const Text(
          AppStrings.voiceDeleteHistoryConfirmBody,
          style: TextStyle(color: AppTheme.textMedium),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              AppStrings.voiceConfirmCancel,
              style: TextStyle(color: AppTheme.textDim),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await context
                  .read<VoiceSettingsCubit>()
                  .clearHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? AppStrings.voiceDeleteHistorySuccess
                          : AppStrings.voiceDeleteHistoryFailed,
                    ),
                  ),
                );
              }
            },
            child: const Text(
              AppStrings.voiceDeleteHistoryConfirmButton,
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primaryOrange,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wake word picker row
// ---------------------------------------------------------------------------

class _WakeWordPicker extends StatelessWidget {
  const _WakeWordPicker({required this.selected, required this.onSelect});

  final WakeWordPreset selected;
  final ValueChanged<WakeWordPreset> onSelect;

  String _pronunciation(WakeWordPreset preset) {
    switch (preset) {
      case WakeWordPreset.samoLevski:
        return AppStrings.wakeWordPronunciationSamoLevski;
      case WakeWordPreset.trainer:
        return AppStrings.wakeWordPronunciationTrainer;
      case WakeWordPreset.thomas:
        return AppStrings.wakeWordPronunciationThomas;
    }
  }

  Key _tileKey(WakeWordPreset preset) {
    switch (preset) {
      case WakeWordPreset.samoLevski:
        return VoiceSettingsPageKeys.wakeWordSamoLevskiKey;
      case WakeWordPreset.trainer:
        return VoiceSettingsPageKeys.wakeWordTrainerKey;
      case WakeWordPreset.thomas:
        return VoiceSettingsPageKeys.wakeWordThomasKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RadioGroup<WakeWordPreset>(
      groupValue: selected,
      onChanged: (WakeWordPreset? v) {
        if (v != null) onSelect(v);
      },
      child: Column(
        children: WakeWordPreset.values.map((WakeWordPreset preset) {
          final bool isSelected = preset == selected;
          return ListTile(
            key: _tileKey(preset),
            leading: Radio<WakeWordPreset>(
              value: preset,
              activeColor: AppTheme.primaryOrange,
            ),
            title: Text(
              preset.displayName,
              style: TextStyle(
                color: isSelected ? AppTheme.textLight : AppTheme.textMedium,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              _pronunciation(preset),
              style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: AppStrings.voiceWakeWordPreviewTooltip,
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              color: AppTheme.textDim,
              onPressed: () => _preview(preset),
            ),
            onTap: () => onSelect(preset),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _preview(WakeWordPreset preset) async {
    final VoiceTtsService tts = sl<VoiceTtsService>();
    await tts.setVolume(1.0);
    await tts.setSpeechRate(VoiceConstants.defaultTtsSpeechRate);
    await tts.speak(preset.displayName);
  }
}

// ---------------------------------------------------------------------------
// Generic slider tile
// ---------------------------------------------------------------------------

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.onChangeEnd,
    super.key,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(color: AppTheme.textLight, fontSize: 15),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            activeColor: AppTheme.primaryOrange,
            inactiveColor: AppTheme.borderMedium,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}
