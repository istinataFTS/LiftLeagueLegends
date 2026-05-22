import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/session_display_name.dart';
import '../../../core/themes/app_theme.dart';
import '../../../domain/entities/app_settings.dart';
// convention-checker:allow=cross-feature-presentation-import reason=home observes ProfileCubit (app-level singleton) for username display; data-observation pattern, not navigation
import '../../../features/profile/application/profile_cubit.dart';
import '../application/home_bloc.dart';
import '../application/muscle_visual_bloc.dart';
import 'home_page_keys.dart';
import 'mappers/home_view_data_mapper.dart';
import 'models/home_view_data.dart';
import 'widgets/home_content.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.settings, super.key});

  final AppSettings settings;

  static const Key pageLoadingIndicatorKey =
      HomePageKeys.pageLoadingIndicatorKey;
  static const Key refreshListKey = HomePageKeys.refreshListKey;
  static const Key progressCardKey = HomePageKeys.progressCardKey;
  static const Key progressLoadingIndicatorKey =
      HomePageKeys.progressLoadingIndicatorKey;
  static const Key progressRetryButtonKey = HomePageKeys.progressRetryButtonKey;
  static const Key homeRetryButtonKey = HomePageKeys.homeRetryButtonKey;
  static const Key macroStripKey = HomePageKeys.macroStripKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (BuildContext context, HomeState homeState) {
            if (homeState is HomeLoading || homeState is HomeInitial) {
              return const Center(
                child: CircularProgressIndicator(
                  key: HomePageKeys.pageLoadingIndicatorKey,
                  color: AppTheme.primaryOrange,
                ),
              );
            }

            if (homeState is HomeError) {
              return _HomeErrorState(
                message: homeState.message,
                onRetry: () {
                  context.read<HomeBloc>().add(const LoadHomeDataEvent());
                },
              );
            }

            final HomeLoaded loadedState = homeState as HomeLoaded;

            return BlocBuilder<MuscleVisualBloc, MuscleVisualState>(
              builder: (BuildContext context, MuscleVisualState muscleState) {
                final ProfileState profileState = context
                    .watch<ProfileCubit>()
                    .state;
                final String userName = SessionDisplayName.resolve(
                  profileState.session,
                  profileState.userProfile,
                );
                final HomePageViewData viewData = HomeViewDataMapper.map(
                  homeData: loadedState.data,
                  muscleVisualState: muscleState,
                  settings: settings,
                  userName: userName,
                );

                return HomeContent(
                  viewData: viewData,
                  onRefresh: () async {
                    context.read<HomeBloc>().add(const RefreshHomeDataEvent());
                    context.read<MuscleVisualBloc>().add(
                      const RefreshVisualsEvent(),
                    );
                  },
                  onPeriodChanged: (period) {
                    context.read<MuscleVisualBloc>().add(
                      ChangePeriodEvent(period),
                    );
                  },
                  onRetryVisuals: () {
                    context.read<MuscleVisualBloc>().add(
                      const RefreshVisualsEvent(),
                    );
                  },
                  onModeChanged: (mode) {
                    context.read<MuscleVisualBloc>().add(ChangeModeEvent(mode));
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(
              AppStrings.error,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              key: HomePageKeys.homeRetryButtonKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
