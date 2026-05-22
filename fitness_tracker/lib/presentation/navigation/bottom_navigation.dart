import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_strings.dart';
import '../../core/themes/app_theme.dart';
import '../../domain/entities/app_settings.dart';
import '../../features/history/history.dart';
import '../../features/home/home.dart';
import '../../features/library/application/exercise_bloc.dart';
import '../../features/library/application/meal_bloc.dart';
import '../../features/library/library.dart';
import '../../features/log/application/nutrition_log_bloc.dart';
import '../../features/log/presentation/pages/log_page.dart';
import '../../features/profile/profile.dart';
import '../../features/settings/presentation/settings_scope.dart';
import '../../features/voice/application/voice_settings_cubit.dart';
import '../../domain/services/voice_wake_word_service.dart';
import '../../features/voice/presentation/widgets/voice_fab.dart';
import '../../injection/injection_container.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({
    super.key,
    this.voiceSettingsCubit,
    this.voiceWakeWordService,
  });

  /// Optional override for [VoiceSettingsCubit]; falls back to
  /// `sl<VoiceSettingsCubit>()` when omitted. Inject in tests to avoid
  /// a GetIt dependency.
  final VoiceSettingsCubit? voiceSettingsCubit;

  /// Optional override for [VoiceWakeWordService]; falls back to
  /// `sl<VoiceWakeWordService>()` when omitted. Inject in tests to avoid
  /// a GetIt dependency.
  final VoiceWakeWordService? voiceWakeWordService;

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  static const int _homeTabIndex = 0;
  static const int _logTabIndex = 1;
  static const int _historyTabIndex = 2;
  static const int _libraryTabIndex = 3;
  static const int _profileTabIndex = 4;
  static const int _tabCount = 5;

  int _selectedIndex = _homeTabIndex;

  final Set<int> _visitedTabs = <int>{_homeTabIndex};

  // Voice FAB dependencies — created once, live for the duration of the
  // navigation shell, then torn down when the scaffold is removed from the tree.
  late final VoiceSettingsCubit _voiceSettingsCubit;
  late final VoiceWakeWordService _voiceWakeWordService;

  bool _didRequestExerciseData = false;
  bool _didRequestMealData = false;
  bool _didRequestNutritionLogData = false;

  @override
  void initState() {
    super.initState();
    _voiceSettingsCubit =
        widget.voiceSettingsCubit ?? sl<VoiceSettingsCubit>();
    _voiceWakeWordService =
        widget.voiceWakeWordService ?? sl<VoiceWakeWordService>();
  }

  @override
  void dispose() {
    // Only close when we own the cubit (i.e., it was not injected via the
    // constructor). Tests pass their own instances and manage lifecycle
    // themselves.
    if (widget.voiceSettingsCubit == null) {
      _voiceSettingsCubit.close();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      return;
    }

    _initializeTabIfNeeded(index);

    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  void _initializeTabIfNeeded(int index) {
    final bool isFirstVisit = !_visitedTabs.contains(index);
    if (!isFirstVisit) {
      return;
    }

    switch (index) {
      case _logTabIndex:
        _ensureExerciseDataLoaded();
        _ensureMealDataLoaded();
        _ensureNutritionLogDataLoaded();
        break;
      case _historyTabIndex:
        _ensureExerciseDataLoaded();
        _ensureMealDataLoaded();
        break;
      case _libraryTabIndex:
        _ensureExerciseDataLoaded();
        _ensureMealDataLoaded();
        break;
      case _homeTabIndex:
      case _profileTabIndex:
        break;
    }
  }

  void _ensureExerciseDataLoaded() {
    if (_didRequestExerciseData) {
      return;
    }

    _didRequestExerciseData = true;
    context.read<ExerciseBloc>().add(LoadExercisesEvent());
  }

  void _ensureMealDataLoaded() {
    if (_didRequestMealData) {
      return;
    }

    _didRequestMealData = true;
    context.read<MealBloc>().add(LoadMealsEvent());
  }

  void _ensureNutritionLogDataLoaded() {
    if (_didRequestNutritionLogData) {
      return;
    }

    _didRequestNutritionLogData = true;
    context.read<NutritionLogBloc>().add(LoadDailyLogsEvent(DateTime.now()));
  }

  Widget _buildPageForIndex(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }

    final AppSettings settings = SettingsScope.of(context);

    switch (index) {
      case _homeTabIndex:
        return HomePage(settings: settings);
      case _logTabIndex:
        return const LogPage();
      case _historyTabIndex:
        return HistoryPage(settings: settings);
      case _libraryTabIndex:
        return const LibraryPage();
      case _profileTabIndex:
        return const ProfilePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ProfileCubit>().state.session;
    return Scaffold(
      floatingActionButton: VoiceFab(
        session: session,
        wakeWordService: _voiceWakeWordService,
        settingsCubit: _voiceSettingsCubit,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: IndexedStack(
        index: _selectedIndex,
        children: List<Widget>.generate(_tabCount, _buildPageForIndex),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderDark)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.surfaceDark,
          selectedItemColor: AppTheme.primaryOrange,
          unselectedItemColor: AppTheme.textDim,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 22),
              activeIcon: Icon(Icons.home, size: 22),
              label: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline, size: 22),
              activeIcon: Icon(Icons.add_circle, size: 22),
              label: AppStrings.navLog,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined, size: 22),
              activeIcon: Icon(Icons.history, size: 22),
              label: AppStrings.navHistory,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books_outlined, size: 22),
              activeIcon: Icon(Icons.library_books, size: 22),
              label: AppStrings.navLibrary,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 22),
              activeIcon: Icon(Icons.person, size: 22),
              label: AppStrings.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
