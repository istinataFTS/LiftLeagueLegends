import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/themes/app_theme.dart';
import '../../../features/settings/application/app_settings_cubit.dart';
import '../../../features/settings/presentation/settings_scope.dart';

/// A card-style section that can be expanded or collapsed by tapping the
/// header. Collapse/expand state is persisted via [AppSettingsCubit] using
/// [id] as the stable key.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
    this.onAddPressed,
    this.addTooltip,
    this.initiallyExpanded = true,
    super.key,
  });

  /// Stable key used to persist expansion state across sessions.
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// Optional widget shown below the subtitle row when expanded.
  final Widget? headerTrailing;

  final VoidCallback? onAddPressed;
  final String? addTooltip;

  /// Fallback used when no persisted state exists for this [id].
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(context),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: widget.child,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      borderRadius: _expanded
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(widget.icon, size: 18, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.onAddPressed != null)
                  IconButton(
                    onPressed: widget.onAddPressed,
                    icon: const Icon(Icons.add),
                    tooltip: widget.addTooltip ?? 'Add',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_less,
                    size: 20,
                    color: AppTheme.textDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
            ),
            if (widget.headerTrailing != null && _expanded) ...<Widget>[
              const SizedBox(height: 12),
              widget.headerTrailing!,
            ],
          ],
        ),
      ),
    );
  }
}
