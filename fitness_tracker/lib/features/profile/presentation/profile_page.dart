import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/themes/app_theme.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../features/auth/presentation/sign_in_page.dart';
import '../../../features/settings/presentation/settings_page.dart';
import '../../../features/voice/application/voice_settings_cubit.dart';
import '../../../features/voice/presentation/voice_settings_page.dart';
import '../../../injection/injection_container.dart';
import '../application/profile_cubit.dart';
import 'mappers/profile_view_data_mapper.dart';
import 'models/profile_view_data.dart';
import 'profile_page_keys.dart';
import 'widgets/profile_content.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Key loadingIndicatorKey = ProfilePageKeys.loadingIndicatorKey;
  static const Key refreshListKey = ProfilePageKeys.refreshListKey;
  static const Key titleKey = ProfilePageKeys.titleKey;
  static const Key subtitleKey = ProfilePageKeys.subtitleKey;
  static const Key sessionBannerKey = ProfilePageKeys.sessionBannerKey;
  static const Key settingsTileKey = ProfilePageKeys.settingsTileKey;
  static const Key accountModeBannerKey = ProfilePageKeys.accountModeBannerKey;

  @override
  Widget build(BuildContext context) {
    return const _ProfileView();
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileCubit>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (ProfileState previous, ProfileState current) =>
          previous.errorMessage != current.errorMessage,
      listener: (BuildContext context, ProfileState state) {
        final String? errorMessage = state.errorMessage;
        if (errorMessage == null || errorMessage.isEmpty) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));

        context.read<ProfileCubit>().clearError();
      },
      builder: (BuildContext context, ProfileState state) {
        final ProfilePageViewData viewData = ProfileViewDataMapper.map(state);

        return Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          appBar: AppBar(
            title: const Text('Profile'),
            automaticallyImplyLeading: false,
            actions: [
              if (state.session.isAuthenticated &&
                  state.userProfile != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                  onPressed: state.isLoading
                      ? null
                      : () =>
                            _showEditProfileSheet(context, state.userProfile!),
                ),
              ],
              if (!state.session.isAuthenticated)
                IconButton(
                  icon: const Icon(Icons.login),
                  tooltip: 'Sign in',
                  onPressed: () async {
                    final ProfileCubit cubit = context.read<ProfileCubit>();
                    final didSignIn = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const SignInPage(),
                      ),
                    );

                    if (!mounted) return;

                    if (didSignIn == true) {
                      await cubit.loadProfile();
                    }
                  },
                ),
              if (state.session.isAuthenticated)
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          await context.read<ProfileCubit>().signOut();
                        },
                ),
            ],
          ),
          body: ProfileContent(
            viewData: viewData,
            onRefresh: () => context.read<ProfileCubit>().refreshProfile(),
            onOpenSettings: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
            onOpenVoiceAssistant: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<VoiceSettingsCubit>(
                    create: (_) => sl<VoiceSettingsCubit>(),
                    child: const VoiceSettingsPage(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context, UserProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditProfileSheet(
        profile: profile,
        onSave: (updated) =>
            context.read<ProfileCubit>().updateProfile(updated),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile bottom sheet
// ---------------------------------------------------------------------------

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile, required this.onSave});

  final UserProfile profile;
  final void Function(UserProfile updated) onSave;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _submit() {
    final String displayName = _displayNameController.text.trim();
    final String bio = _bioController.text.trim();

    final UserProfile updated = widget.profile.copyWith(
      displayName: displayName.isNotEmpty ? displayName : null,
      clearDisplayName: displayName.isEmpty,
      bio: bio.isNotEmpty ? bio : null,
      clearBio: bio.isEmpty,
      updatedAt: DateTime.now(),
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Edit Profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '@${widget.profile.username}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Your name as shown to others',
            ),
            textInputAction: TextInputAction.next,
            maxLength: 50,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText: 'A short description about yourself',
            ),
            maxLines: 3,
            maxLength: 160,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _submit, child: const Text('Save')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
