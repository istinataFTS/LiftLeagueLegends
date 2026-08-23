import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import 'lift_bottom_nav.dart';

/// The five-destination app shell.
///
/// Pages are a [PageView], not an [IndexedStack]: a horizontal swipe is the
/// primary way to move between them and the bar is the secondary one. Each
/// page keeps its state across swipes via [_KeepAlivePage] — losing a Library
/// search or a Log tab selection every time the user swipes past a page would
/// make the gesture unusable.
///
/// The bar hides while the active page is scrolled down and comes back on the
/// first upward scroll, so a long list gets the whole screen.
class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with SingleTickerProviderStateMixin {
  static const int _homeTabIndex = 0;
  static const int _logTabIndex = 1;
  static const int _historyTabIndex = 2;
  static const int _libraryTabIndex = 3;
  static const int _profileTabIndex = 4;
  static const int _tabCount = 5;

  /// Long enough to read as a move between two pages, short enough that a tap
  /// on the bar still feels immediate.
  static const Duration _pageMotion = Duration(milliseconds: 260);
  static const Duration _barMotion = Duration(milliseconds: 200);

  int _selectedIndex = _homeTabIndex;

  final Set<int> _visitedTabs = <int>{_homeTabIndex};

  bool _didRequestNutritionLogData = false;

  /// Opens on Home, which is index 0 — the controller's own default.
  late final PageController _pageController = PageController();

  /// 1 = bar fully shown, 0 = fully collapsed below the bottom edge.
  late final AnimationController _barController = AnimationController(
    duration: _barMotion,
    vsync: this,
    value: 1,
  );

  @override
  void dispose() {
    _pageController.dispose();
    _barController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      return;
    }

    // Dispatched here rather than from `onPageChanged` so a tap loads the
    // destination's data on the same frame, before the page animation runs.
    _initializeTabIfNeeded(index);

    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
    _showBar();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: _pageMotion,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Fires when a swipe settles on a new page, and part-way through the
  /// animation a tap starts. Both paths are idempotent.
  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      _initializeTabIfNeeded(index);
      setState(() {
        _selectedIndex = index;
        _visitedTabs.add(index);
      });
    }
    // A page arriving under a hidden bar would leave no visible way back out
    // of it.
    _showBar();
  }

  /// Builds the pages either side of the current one the moment a horizontal
  /// drag begins, so a swipe reveals the destination rather than the blank
  /// placeholder an unvisited index renders. No data is dispatched here —
  /// that waits until the swipe settles on the page.
  void _prepareNeighbours() {
    final Set<int> neighbours = <int>{
      _selectedIndex - 1,
      _selectedIndex + 1,
    }.where((int i) => i >= 0 && i < _tabCount).toSet();
    if (neighbours.every(_visitedTabs.contains)) return;
    setState(() => _visitedTabs.addAll(neighbours));
  }

  void _showBar() {
    if (!_barController.isCompleted) _barController.forward();
  }

  void _hideBar() {
    if (!_barController.isDismissed) _barController.reverse();
  }

  /// Hide-on-scroll, driven by whichever scrollable the active page owns.
  ///
  /// Only vertical scrolls count — the [PageView]'s own horizontal drags
  /// surface here too, and a swipe between pages must not move the bar. A
  /// page that cannot scroll is ignored as well: Home is exactly
  /// viewport-tall and keeps `AlwaysScrollableScrollPhysics` alive for
  /// pull-to-refresh, so its refresh drag would otherwise hide the bar on a
  /// screen with nothing to scroll.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      if (notification is ScrollStartNotification) _prepareNeighbours();
      return false;
    }

    if (notification is! UserScrollNotification) return false;
    if (notification.metrics.maxScrollExtent <= 0) return false;

    switch (notification.direction) {
      case ScrollDirection.reverse:
        _hideBar();
      case ScrollDirection.forward:
        _showBar();
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  void _initializeTabIfNeeded(int index) {
    switch (index) {
      case _logTabIndex:
        _ensureExerciseDataLoaded();
        _ensureMealDataLoaded();
        _ensureNutritionLogDataLoaded();
        break;
      case _historyTabIndex:
      case _libraryTabIndex:
        _ensureExerciseDataLoaded();
        _ensureMealDataLoaded();
        break;
      case _homeTabIndex:
      case _profileTabIndex:
        break;
    }
  }

  /// Dispatches [LoadExercisesEvent] unless the bloc already holds a healthy
  /// (non-empty) loaded state. Guarding on state rather than a one-shot bool
  /// means a transient empty or error result is re-queried on the next tab
  /// entry without requiring an app restart.
  void _ensureExerciseDataLoaded() {
    final state = context.read<ExerciseBloc>().state;
    if (state is ExerciseLoading) {
      return;
    }
    if (state is ExercisesLoaded && state.exercises.isNotEmpty) {
      return;
    }
    context.read<ExerciseBloc>().add(LoadExercisesEvent());
  }

  /// Dispatches [LoadMealsEvent] unless the bloc already holds a healthy
  /// (non-empty) loaded state.
  void _ensureMealDataLoaded() {
    final state = context.read<MealBloc>().state;
    if (state is MealLoading) {
      return;
    }
    if (state is MealsLoaded && state.meals.isNotEmpty) {
      return;
    }
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
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _tabCount,
          onPageChanged: _onPageChanged,
          itemBuilder: (BuildContext context, int index) =>
              _KeepAlivePage(child: _buildPageForIndex(index)),
        ),
      ),
      // Collapsing from the top edge sinks the bar below the bottom of the
      // screen rather than shrinking it in place, and hands the space back to
      // the page instead of covering content with an overlay.
      bottomNavigationBar: SizeTransition(
        sizeFactor: _barController,
        axisAlignment: -1,
        child: LiftBottomNav(
          selectedIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

/// Keeps a page's `State` alive while the [PageView] scrolls it out of range.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
