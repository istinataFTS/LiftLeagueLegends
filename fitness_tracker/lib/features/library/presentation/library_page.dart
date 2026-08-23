import 'package:flutter/material.dart';

import '../../../core/themes/lift_theme.dart';
import '../../../presentation/shared/widgets/lift_tab_selector.dart';
import 'library_strings.dart';
import 'widgets/exercises_tab.dart';
import 'widgets/library_chrome.dart';
import 'widgets/meals_tab.dart';

/// Library, rebuilt from frames 11 and 12 of the Deep Mist export.
///
/// Three things the frame removes that the pre-restyle page had, all of them
/// owned here and not by either tab:
///
///   * the opaque `backgroundColor`, which painted over [LiftGround];
///   * the two `Tab` icons — frame 11's tabs are text only;
///   * the `info_outline` AppBar action and its dialog. Frame 11 shows a bare
///     `Library` title with nothing on its right, and the copy that dialog
///     carried only ever restated what the two tabs plainly do.
///
/// The `TabBar` goes with them: the tab strip is [LiftTabSelector], the same
/// control Log's three sub-tabs use, so the two screens cannot drift apart.
///
/// ### The header scrolls
///
/// There is no `AppBar`. The title and the tab strip are **slivers handed to
/// the active tab**, which stacks them above its own search row and list
/// inside one [CustomScrollView]. A fixed header over an `Expanded` list held
/// a third of the screen open permanently while the only part anybody reads
/// scrolled inside what was left. Now the title scrolls away and the strip
/// pins itself under it ([LibraryPinnedTabs]), so a scrolled list has the
/// whole screen and the other tab is still one tap away.
///
/// ### The tabs do not swipe
///
/// [TabBarView] is gone, replaced by an [IndexedStack]. A horizontal swipe is
/// the app's primary navigation between the five main pages, and a nested
/// horizontal scrollable always wins that gesture from its parent — keeping
/// the inner swipe would have made Library the one page the main navigation
/// gesture could not leave. The strip switches tabs on tap; the stack keeps
/// both tabs' search text and filters alive across the switch.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  static const Key tabSelectorKey = ValueKey<String>('library_tab_selector');

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  /// Frame 11: the title's line box opens 12dp below the status bar.
  static const double _titleTopPad = 12;

  int _selectedTab = 0;

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
  }

  /// The title and the pinned strip, in the order both tabs stack them.
  List<Widget> get _headerSlivers => <Widget>[
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          libraryGutter,
          _titleTopPad,
          libraryGutter,
          0,
        ),
        child: Text(LibraryStrings.title, style: LiftText.headlineMedium),
      ),
    ),
    SliverPersistentHeader(
      pinned: true,
      delegate: LibraryPinnedTabs(
        strip: LiftTabSelector(
          key: LibraryPage.tabSelectorKey,
          labels: const <String>[
            LibraryStrings.exercisesTab,
            LibraryStrings.mealsTab,
          ],
          keyPrefix: 'library-tab',
          selectedIndex: _selectedTab,
          onChanged: _selectTab,
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> headerSlivers = _headerSlivers;

    // Only the visible tab is handed the header. `IndexedStack` builds both
    // children — that is what keeps the hidden tab's search text and filters
    // alive — so giving both a header would put two copies of the title and
    // two tab strips in the tree at once.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedTab,
          children: <Widget>[
            ExercisesTab(
              headerSlivers: _selectedTab == 0
                  ? headerSlivers
                  : const <Widget>[],
            ),
            MealsTab(
              headerSlivers: _selectedTab == 1
                  ? headerSlivers
                  : const <Widget>[],
            ),
          ],
        ),
      ),
    );
  }
}
