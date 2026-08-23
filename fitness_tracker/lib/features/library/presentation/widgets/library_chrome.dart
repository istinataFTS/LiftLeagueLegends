/// The chrome both Library tabs share, rebuilt from frame 11.
///
/// Every size here was measured off `11-library-exercises.png` (1176x2538 =
/// 392x846dp at 3x) rather than eyeballed, and the comment on each constant
/// records what was measured. The frames use slightly tighter mono tracking
/// than `LiftText`'s label tokens do; where the two disagree the token wins,
/// because the tokens are what Log, Home and History already render.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/themes/lift_theme.dart';
import '../library_strings.dart';

/// Page gutter. Frame 11 puts the search box, every rule and the CTA at
/// x=63px at 3x, i.e. 21dp; this rounds to the 20dp Home and History already
/// use so the four screens line up with each other.
const double libraryGutter = 20;

/// Frame 11: consecutive row rules sit 189px apart at 3x = 63dp. That falls
/// out of 13dp padding + a 15dp name + 5dp + a 9.5dp meta line + 13dp + 1dp
/// rule, which is what [LibraryListRow] builds.
const double _rowPadV = 13.5;

/// Frame 11: the meta line's cap top sits ~14px at 3x below the name's line
/// box.
const double _rowNameToMeta = 3;

/// Search box: outer height 117px at 3x = 39dp.
const double _searchPadV = 10;

/// Filter chips: 84px tall at 3x with an 18px gap = 28dp and 6dp.
const double _chipHeight = 28;
const double _chipGap = 6;

/// Frame 11: an unselected chip's label ink is inset 42px at 3x from the chip
/// edge; 14dp minus the 1.5dp border is what produces that.
const double _chipPadH = 12.5;

/// Frame 11's filter row runs off the right edge of the screen under a fade,
/// which is how the design signals that it scrolls.
const double _chipFadeWidth = 28;

/// Library's search box (frame 11).
///
/// Square, 1.5dp `border`, `actionTint` on focus — all of that comes from
/// `LiftTheme`'s `inputDecorationTheme`. What this widget adds is the frame's
/// tighter vertical padding, its `bodyMedium` hint (the theme default is
/// `bodyLarge`, which measures 5px too tall against the frame at 3x) and the
/// `textDim` magnifier.
class LibrarySearchField extends StatelessWidget {
  const LibrarySearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.fieldKey,
    this.clearButtonKey,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Key? fieldKey;
  final Key? clearButtonKey;

  @override
  Widget build(BuildContext context) {
    final bool hasQuery = controller.text.isNotEmpty;

    return TextField(
      key: fieldKey,
      controller: controller,
      onChanged: onChanged,
      style: LiftText.bodyMedium.copyWith(color: LiftColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: LiftText.bodyMedium.copyWith(color: LiftColors.textFaint),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: _searchPadV),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 5),
          child: Icon(Icons.search, size: 16, color: LiftColors.textDim),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: hasQuery
            ? IconButton(
                key: clearButtonKey,
                icon: const Icon(Icons.clear, size: 16),
                color: LiftColors.textDim,
                onPressed: onClear,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
      ),
    );
  }
}

/// One square filter chip (frame 11).
///
/// Selected fills `actionFill` with white; unselected is transparent behind a
/// 1.5dp `border`. Neither state is rounded and neither carries a checkmark —
/// frame 12 reserves a checkmark slot on its selected chips but draws nothing
/// in it, which only pushes the label off centre, so the slot is dropped and
/// the label is centred in both states.
class LibraryFilterChip extends StatelessWidget {
  const LibraryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.chipKey,
    this.height = _chipHeight,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key? chipKey;

  /// Frame 11's filter row measures 28dp; frame 12's dialog chips measure 30.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // The node needs its own `onTap`: `excludeSemantics` drops the
      // GestureDetector's semantics with the rest of the subtree.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: chipKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: _chipPadH),
          decoration: BoxDecoration(
            color: selected ? LiftColors.actionFill : Colors.transparent,
            border: selected
                ? null
                : Border.all(
                    color: LiftColors.border,
                    width: LiftShape.borderWidth,
                  ),
          ),
          // `Center` with `widthFactor: 1` and not `Container.alignment`:
          // `alignment` wraps the child in an `Align` that expands to the
          // incoming constraints, which inside a `Wrap` means every chip
          // takes the full row.
          child: Center(
            widthFactor: 1,
            child: Text(
              label.toUpperCase(),
              style: LiftText.labelLarge.copyWith(
                color: selected ? Colors.white : LiftColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The horizontally scrolling filter row, faded at its right edge.
class LibraryFilterChipRow extends StatelessWidget {
  const LibraryFilterChipRow({required this.chips, super.key});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _chipHeight,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          final double stop = bounds.width <= _chipFadeWidth
              ? 0
              : 1 - _chipFadeWidth / bounds.width;
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const <Color>[
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: <double>[0, stop, 1],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: libraryGutter),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: _chipGap),
          itemBuilder: (BuildContext context, int index) => chips[index],
        ),
      ),
    );
  }
}

/// `53 OF 53 EXERCISES` (frame 11) — mono caps, `textDim`.
class LibraryCountLabel extends StatelessWidget {
  const LibraryCountLabel({required this.label, this.labelKey, super.key});

  final String label;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: libraryGutter),
      child: Text(
        label,
        key: labelKey,
        style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
      ),
    );
  }
}

/// One Library row: a name over a mono meta line, closed by a hairline rule.
///
/// The frames draw no per-row controls at all — no icon tile, no `⋮` menu, no
/// edit or delete button. Under the owner's standing ruling the controls go
/// and their function is re-homed on the row itself: tap to edit, long-press
/// to delete. Both are published as semantics actions so the row is not left
/// unreachable without a pointer.
class LibraryListRow extends StatelessWidget {
  const LibraryListRow({
    required this.title,
    required this.meta,
    required this.onTap,
    required this.onLongPress,
    required this.editHint,
    required this.deleteHint,
    this.secondaryMeta,
    super.key,
  });

  final String title;

  /// Mono caps under the name, already joined with
  /// [LibraryStrings.metaSeparator].
  final String meta;

  /// Meals carry a second mono line (`21P · 22C · 49F`); exercises do not.
  final String? secondaryMeta;

  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String editHint;
  final String deleteHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: editHint): onTap,
        CustomSemanticsAction(label: deleteHint): onLongPress,
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: LiftColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: libraryGutter,
            vertical: _rowPadV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: LiftText.titleMedium.copyWith(
                  color: LiftColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: _rowNameToMeta),
              Text(
                meta,
                style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (secondaryMeta != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  secondaryMeta!,
                  style: LiftText.labelMedium.copyWith(
                    color: LiftColors.textFaint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-width `+ ADD EXERCISE` CTA (frame 11).
///
/// Frame 11 draws it 47dp tall against the theme's 52dp `ElevatedButton`, and
/// its label a shade larger than `labelLarge`. Both deltas are shared with
/// frame 02's `LOG SET`, which PR B2 already resolved in the theme's favour;
/// resolving it the other way here would make Library's CTA the only one in
/// the app that is not the theme's.
///
/// The `+` is part of the label rather than an [Icon] because the frame draws
/// a mono plus one advance wide, not a Material glyph.
/// The compact `+ ADD` control that rides the right-hand end of the search
/// row (frames 11 and 12 put the action in a full-width dock at the bottom of
/// the page instead).
///
/// The dock cost a permanent 88dp band at the bottom of a list that is
/// already the whole point of the screen, and it sat directly on top of the
/// app's bottom navigation — two stacked bars competing for the same edge.
/// Here the action is one row up, beside the field it belongs with, and the
/// list runs to the bottom of the screen.
///
/// The label is deliberately just `+ ADD`: what is being added is named by
/// the tab strip two lines above it, and the assistive-technology label
/// carries the long form. It is not an `ElevatedButton` because the theme
/// gives those a `Size.fromHeight(52)` minimum, and this one has to match the
/// search field beside it.
class LibraryAddButton extends StatelessWidget {
  const LibraryAddButton({
    required this.semanticLabel,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  /// Long form, e.g. `Add exercise` — the visible label is always `+ ADD`.
  final String semanticLabel;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      // The node needs its own `onTap`: `excludeSemantics` drops the
      // GestureDetector's semantics with the rest of the subtree.
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          key: buttonKey,
          alignment: Alignment.center,
          // The search field measures ~42dp, and `LibraryBrowseBar` stretches
          // both to the taller of the two — so this floor lifts the field to
          // 44dp as well and the pair stays aligned at a legal tap target.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: LiftColors.actionFill,
            borderRadius: BorderRadius.circular(LiftShape.radiusButton),
          ),
          child: Text(
            '+ ADD',
            style: LiftText.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// The search field with [LibraryAddButton] on its right.
///
/// `IntrinsicHeight` is what keeps the two the same height: the field sizes
/// itself from its own content padding and the button has no height of its
/// own, so stretching it against the field's intrinsic height is the only way
/// the pair stays aligned when the text scale moves.
class LibraryBrowseBar extends StatelessWidget {
  const LibraryBrowseBar({
    required this.searchField,
    required this.addButton,
    super.key,
  });

  final Widget searchField;
  final Widget addButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: libraryGutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: searchField),
            const SizedBox(width: 10),
            addButton,
          ],
        ),
      ),
    );
  }
}

/// The `EXERCISES / MEALS` strip as a pinned sliver header.
///
/// Everything above it — the page title — scrolls away; the strip stays so
/// the other tab is always one tap away. It draws nothing while it is resting
/// in its own place in the list, and fades a [LiftColors.panelTop] slab and a
/// hairline in once rows start passing underneath it, because a transparent
/// strip with list rows sliding through the letterforms is unreadable.
///
/// The fade is driven by `shrinkOffset`, not by the `overlapsContent` flag —
/// that flag is `constraints.overlap > 0`, which only becomes true when an
/// *earlier* pinned sliver pushes this one out of place, and there is no such
/// sliver here.
class LibraryPinnedTabs extends SliverPersistentHeaderDelegate {
  const LibraryPinnedTabs({required this.strip});

  /// [LiftTabSelector], already keyed and wired by the page.
  final Widget strip;

  /// [LiftTabSelector] is a fixed 44dp for touch compliance.
  static const double _stripHeight = 44;

  /// The slab reaches full strength this many pixels into the scroll.
  static const double _fadeDistance = 12;

  @override
  double get minExtent => _stripHeight;

  @override
  double get maxExtent => _stripHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double t = (shrinkOffset / _fadeDistance).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(Colors.transparent, LiftColors.panelTop, t),
        border: Border(
          bottom: BorderSide(
            color: Color.lerp(Colors.transparent, LiftColors.rule, t)!,
            width: LiftShape.borderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: libraryGutter),
        child: strip,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant LibraryPinnedTabs oldDelegate) =>
      oldDelegate.strip != strip;
}

/// How long a pull-to-refresh waits for the bloc before giving up.
const Duration _refreshTimeout = Duration(seconds: 10);

/// The scroll view both Library tabs are built on.
///
/// One `CustomScrollView` carries the page header, the browse controls and
/// the rows, so all three move together — a fixed header over an `Expanded`
/// list meant a third of the screen never moved however far the list was
/// scrolled.
class LibraryTabScrollView extends StatelessWidget {
  const LibraryTabScrollView({
    required this.onRefresh,
    required this.slivers,
    super.key,
  });

  /// Dispatches the tab's reload and completes when the bloc settles.
  final Future<void> Function() onRefresh;

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: LiftColors.actionTint,
      backgroundColor: LiftColors.background,
      onRefresh: _refresh,
      child: CustomScrollView(
        // Keeps the refresh drag alive on the empty and no-results states,
        // which fill the viewport exactly and so have nothing to scroll.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  /// The spinner has to stop whatever the bloc does.
  ///
  /// Both tabs resolve a refresh by waiting for the next terminal state. A
  /// bloc that never reaches one would leave the indicator turning for the
  /// life of the page, and one that closes first makes `firstWhere` throw a
  /// `StateError` into the indicator's future. Neither is worth surfacing:
  /// the list still shows whatever was last emitted, and a genuine failure
  /// arrives as an error state that renders itself.
  Future<void> _refresh() async {
    try {
      await onRefresh().timeout(_refreshTimeout);
    } catch (_) {
      // Deliberately swallowed — see above.
    }
  }
}

/// Fills whatever height is left below the header.
///
/// `hasScrollBody` stays at its default `true` even though these states do
/// not look like scroll bodies: [LibraryMessageState] centres itself inside
/// its own `SingleChildScrollView` so it can still be read at an
/// accessibility text scale, and the `LayoutBuilder` driving that centring
/// cannot answer the intrinsic-height query `hasScrollBody: false` puts to
/// its child.
Widget librarySliverFill(Widget child) => SliverFillRemaining(child: child);

/// Shared body for the empty, no-results and error states.
///
/// No frame draws any of them, so they keep a visible button — the same
/// licence PR B4 took with History's empty states.
class LibraryMessageState extends StatelessWidget {
  const LibraryMessageState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.secondaryActionKey,
    this.titleColor,
    super.key,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final Key? secondaryActionKey;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: libraryGutter,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight - 64).clamp(0, double.infinity)
                  : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.toUpperCase(),
                  style: LiftText.labelMedium.copyWith(
                    color: titleColor ?? LiftColors.textDim,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: LiftText.bodyMedium.copyWith(
                    color: LiftColors.textSecondary,
                  ),
                ),
                if (actionLabel != null) ...<Widget>[
                  const SizedBox(height: 22),
                  IntrinsicWidth(
                    child: ElevatedButton(
                      key: actionKey,
                      onPressed: onAction,
                      child: Text(actionLabel!.toUpperCase()),
                    ),
                  ),
                ],
                if (secondaryActionLabel != null) ...<Widget>[
                  const SizedBox(height: 10),
                  IntrinsicWidth(
                    child: OutlinedButton(
                      key: secondaryActionKey,
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!.toUpperCase()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Frame 12's modal panel: `panelTop` over the scrim, square, a 1.5dp
/// `borderStrong` edge and the design system's only shadow.
///
/// Both Library dialogs use it so the exercise panel and the meal panel — of
/// which no frame exists — cannot drift apart.
class LibraryPanel extends StatelessWidget {
  const LibraryPanel({required this.content, required this.footer, super.key});

  /// Scrolls; the footer does not.
  final Widget content;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Frame 12: the panel is inset 16dp from each screen edge.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: LiftColors.panelTop,
          border: Border.fromBorderSide(
            BorderSide(
              color: LiftColors.borderStrong,
              width: LiftShape.borderWidth,
            ),
          ),
          boxShadow: LiftElevation.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: content),
            footer,
          ],
        ),
      ),
    );
  }
}

/// A `NAME` / `MUSCLE GROUPS` style field label inside a [LibraryPanel].
class LibraryFieldLabel extends StatelessWidget {
  const LibraryFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
    );
  }
}
