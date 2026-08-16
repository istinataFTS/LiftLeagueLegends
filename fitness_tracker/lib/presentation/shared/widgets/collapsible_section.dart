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
/// The header carries exactly two lines: [title] in Space Grotesk bold and
/// [subtitle] in dim letterspaced mono caps. The pre-restyle version of this
/// widget also drew a leading icon, a trailing `+` button, a rotating chevron,
/// and an optional `headerTrailing` chip row. **All four are gone**, because
/// none of them appear anywhere in the frames — the whole header is the tap
/// target instead, and the actions those controls carried moved onto the rows
/// and empty states that own them.
///
/// Collapse/expand state is persisted via [AppSettingsCubit] using [id] as the
/// stable key, unchanged from before the restyle.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = true,
    super.key,
  });

  /// Stable key used to persist expansion state across sessions.
  final String id;
  final String title;
  final String subtitle;
  final Widget child;

  /// Fallback used when no persisted state exists for this [id].
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  static const double _gutter = 20;

  late bool _expanded;
  Timer? _persistDebounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefer the persisted state; fall back to the widget default.
    final settings = SettingsScope.maybeOf(context);
    _expanded =
        settings?.uiExpansionState[widget.id] ?? widget.initiallyExpanded;
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);

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
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _gutter,
                        0,
                        _gutter,
                        8,
                      ),
                      child: widget.child,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 14),
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
                style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
