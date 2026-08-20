import 'package:flutter/material.dart';

import '../../../core/themes/lift_theme.dart';
import '../../../presentation/shared/widgets/lift_tab_selector.dart';
import 'library_strings.dart';
import 'widgets/exercises_tab.dart';
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
/// It sits in the AppBar's `bottom`, which puts the theme's AppBar rule below
/// the strip and lets it run the full width of the screen, as frame 11 draws
/// it.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  static const Key tabSelectorKey = ValueKey<String>('library_tab_selector');

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// The horizontal inset shared by the tab strip and by both tabs' content.
  static const double _gutter = 20;

  /// Frame 11: the title's line box opens 12dp below the status bar.
  static const double _titleTopPad = 12;

  /// 12dp pad + the 26dp title's 1.1 line box + [LiftTabSelector]'s 44dp.
  /// The line box is 28.6dp on paper and lays out at 29 — `PreferredSize`
  /// takes a fixed height, so it gets the laid-out one.
  static const double _headerHeight = _titleTopPad + 29 + 44;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Keeps the strip in step with a swipe on the [TabBarView], which moves the
  /// controller without going through [LiftTabSelector.onChanged].
  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        // The whole header lives in `bottom`, and the toolbar is collapsed to
        // nothing. Frame 11 stacks the title directly on the tab strip: a
        // Material toolbar centres its title in a 56dp band, which opens a
        // 35dp gap where the frame draws 18dp, and no `toolbarHeight` closes
        // it — shrinking the band moves the title down half as fast as it
        // moves the strip up, and the band would have to go below the title's
        // own line box before the two met. `bottom` still sits above the
        // theme's AppBar rule, so the rule keeps running the full width under
        // the strip, which is what the frame draws.
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(_headerHeight),
          // `AppBar` hands `bottom` a loose width constraint, so a bare
          // Column shrink-wraps to its widest child and centres — the title
          // and the tab strip end up mid-screen. The SizedBox pins it open.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    _gutter,
                    _titleTopPad,
                    _gutter,
                    0,
                  ),
                  child: Text(
                    LibraryStrings.title,
                    style: LiftText.headlineMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                  child: LiftTabSelector(
                    key: LibraryPage.tabSelectorKey,
                    labels: const <String>[
                      LibraryStrings.exercisesTab,
                      LibraryStrings.mealsTab,
                    ],
                    keyPrefix: 'library-tab',
                    selectedIndex: _tabController.index,
                    onChanged: _tabController.animateTo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[ExercisesTab(), MealsTab()],
      ),
    );
  }
}
