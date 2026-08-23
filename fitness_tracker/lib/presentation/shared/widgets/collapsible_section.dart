import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/themes/lift_theme.dart';
import '../../../features/settings/application/app_settings_cubit.dart';
import '../../../features/settings/presentation/settings_scope.dart';

/// A full-bleed section of the page that expands and collapses when its header
/// is tapped, styled from History frames 09 (`09-history-workout-expanded.png`)
/// and 10 (`10-history-nutrition-expanded.png`) of the Deep Mist export.
///
/// The design export lives outside this repository and is not checked in.
///
/// The section is **not a card**. It sits directly on the ground and is bounded
/// above by a full-width rule, edge to edge — the header's 20dp gutter applies
/// to the text only, never to the rule. There is no fill, no radius, and no
/// shadow, in line with the spec's SHAPE note ("square edges throughout; 8px
/// only on buttons").
///
/// The header carries two lines — [title] in Space Grotesk bold and [subtitle]
/// in dim letterspaced mono caps — plus an optional [trailing] control. The
/// pre-restyle version also drew a leading icon, a rotating chevron, and a
/// `headerTrailing` chip row; those are gone, and the whole two-line block is
/// the collapse target instead.
///
/// ### Press feedback and motion
///
/// The header's press feedback is a full-row wash, not a Material splash. The
/// splash was clipped to the text column, so pressing the header lit a grey
/// block that stopped short of [trailing] and read as if the `+` belonged to
/// something else. The row is one ink target now — [trailing] included — and
/// the wash is [LiftColors.surfaceSunken], fading in and out with the ink
/// highlight. No ripple, no circle expanding out of the touch point.
///
/// Expand and collapse are one [AnimationController] played forward and in
/// reverse, so the two directions are exact mirrors: height eases on
/// [Curves.easeInOutCubic] while the body cross-fades inside that window. The
/// previous shape — `AnimatedSize` over a child swapped for a `SizedBox` —
/// dropped the body at full opacity the instant a collapse began and animated
/// only the box, which is what made it feel stiff.
///
/// Collapse/expand state is persisted via [AppSettingsCubit] using [id] as the
/// stable key, unchanged from before the restyle.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.initiallyExpanded = true,
    super.key,
  });

  /// Stable key used to persist expansion state across sessions.
  final String id;
  final String title;
  final String subtitle;
  final Widget child;

  /// Optional control pinned to the right of the header.
  ///
  /// It sits *inside* the header's ink target so the press wash covers the
  /// whole row and the control reads as part of the section, but it keeps its
  /// own gesture recogniser: a tap landing on it wins the arena as the deeper
  /// hit-test entry, so pressing it does not also collapse the section.
  ///
  /// History's workout section uses it for the `add a set to this day` `+`.
  /// That action has nowhere else to live: the section's empty-state call to
  /// action is the only other place it appears, and a day that already has
  /// sets never shows an empty state.
  final Widget? trailing;

  /// Fallback used when no persisted state exists for this [id].
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  static const double _gutter = 20;
  static const Duration _motion = Duration(milliseconds: 320);

  late final AnimationController _controller = AnimationController(
    duration: _motion,
    vsync: this,
  );

  /// Height drives the whole window; the body's opacity rides a shorter slice
  /// of it at each end so content never fades over an empty box.
  late final CurvedAnimation _extent = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 1, curve: Curves.easeOut),
    reverseCurve: const Interval(0.3, 1, curve: Curves.easeIn),
  );

  bool _expanded = true;
  bool _synced = false;
  Timer? _persistDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromSettings();
  }

  @override
  void didUpdateWidget(CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id == oldWidget.id &&
        widget.initiallyExpanded == oldWidget.initiallyExpanded) {
      return;
    }
    // The state this section shows belongs to [CollapsibleSection.id], and
    // `didChangeDependencies` only fires when `SettingsScope` changes — a
    // parent swapping the id on a retained `State` would otherwise leave the
    // previous section's expansion showing under the new one's name. Both
    // call sites pass a `const` id today, so this is a guard on the shared
    // widget rather than a fix for a live bug.
    //
    // Any write still queued belongs to the id that was on screen when the
    // press happened, and that section is gone.
    _persistDebounce?.cancel();
    _syncFromSettings();
  }

  /// Prefers the persisted state and falls back to [widget.initiallyExpanded].
  /// A value arriving from settings is applied without animating — only a
  /// press animates.
  void _syncFromSettings() {
    final settings = SettingsScope.maybeOf(context);
    final bool expanded =
        settings?.uiExpansionState[widget.id] ?? widget.initiallyExpanded;
    if (_synced && expanded == _expanded) return;
    _synced = true;
    _expanded = expanded;
    _controller.value = expanded ? 1 : 0;
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _extent.dispose();
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });

    // Debounce writes — the user might rapidly tap the header.
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.read<AppSettingsCubit>().setSectionExpanded(
        widget.id,
        expanded: _expanded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context),
          AnimatedBuilder(
            animation: _controller,
            // Handed in as `child` so the body is built once per frame of the
            // parent rather than once per animation tick. It is only mounted
            // while the controller is off its resting collapsed value, so a
            // collapsed section still puts nothing findable in the tree.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 8),
              child: widget.child,
            ),
            builder: (BuildContext context, Widget? child) {
              if (_controller.isDismissed) {
                return const SizedBox(width: double.infinity);
              }
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _extent.value,
                  child: Opacity(
                    opacity: _opacity.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final Widget? trailing = widget.trailing;

    return Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        onTap: _toggle,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: LiftColors.surfaceSunken,
        hoverColor: LiftColors.surfaceSunken,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _gutter,
            16,
            // A trailing control carries its own 44dp touch box, so the row
            // stops 10dp short and the glyph still lands on the gutter.
            trailing == null ? _gutter : _gutter - 10,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: trailing == null ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.title,
                        style: LiftText.titleMedium.copyWith(
                          color: LiftColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle.toUpperCase(),
                        style: LiftText.labelMedium.copyWith(
                          color: LiftColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
