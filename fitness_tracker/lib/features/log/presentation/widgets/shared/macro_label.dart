import 'package:flutter/material.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/themes/lift_theme.dart';

/// Which macro a [MacroLabel] identifies.
///
/// Bundles the display label and the swatch [Color] together on purpose: the
/// review that flagged the three pre-extraction copies of this element found
/// that, because each call site independently chose both a label string and
/// a raw [Color], protein and carbs had already been silently swapped on two
/// of the three tabs and every existing test still passed. Routing both
/// through one enum makes that class of mistake require mismatching an enum
/// value against its own label, which is a much louder mistake to make (and
/// to review) than transposing two `Color` constants a few lines apart.
enum MacroKind {
  protein,
  carbs,
  fats;

  String get label => switch (this) {
    MacroKind.protein => AppStrings.protein,
    MacroKind.carbs => AppStrings.carbs,
    MacroKind.fats => AppStrings.fats,
  };

  Color get color => switch (this) {
    MacroKind.protein => LiftColors.protein,
    MacroKind.carbs => LiftColors.carbs,
    MacroKind.fats => LiftColors.fats,
  };
}

/// The two treatments the design frames (`06-log-meal-picked.png`,
/// `07-log-macros.png`) actually show for a macro swatch+name pair:
///
///  - [caption]: small dim swatch+name sitting underneath a value. The
///    "Today so far" cells and the Meal tab's this-entry preview stats
///    render pixel-identically at this treatment in both frames (9x9
///    swatch, 6px gap, `labelMedium`, `textDim`) — confirmed by cropping and
///    measuring both frames' swatch bounding boxes during the fix for the
///    finding that flagged this widget.
///  - [header]: larger, bright swatch+name leading an editable macro row.
///    The Macros tab's PROTEIN/CARBS/FATS row headers measure a visibly
///    bigger swatch (~26px vs ~17-20px in the frame's native pixels) and
///    render in full `textPrimary` white rather than dim grey — a
///    deliberately different, more prominent treatment because the row it
///    leads is the one being edited, not a passive readout.
enum MacroLabelVariant { caption, header }

/// Shared swatch-and-caption element for identifying a macro (protein/carbs/
/// fats) by colour.
///
/// Used by [LogTodaySoFarCard]'s per-macro cells, [LogMealTab]'s this-entry
/// preview row, and [LogMacrosTab]'s per-macro row headers — previously each
/// of those reimplemented this independently with a different swatch size,
/// gap, text style, and (per the finding that prompted this extraction) risk
/// of a mismatched colour.
class MacroLabel extends StatelessWidget {
  const MacroLabel({
    super.key,
    required this.kind,
    this.variant = MacroLabelVariant.caption,
    this.swatchKey,
  });

  final MacroKind kind;
  final MacroLabelVariant variant;

  /// Optional key applied to the swatch square, so call sites migrating an
  /// existing keyed swatch (e.g. `today-swatch-protein`, read by an existing
  /// test) can keep that exact key.
  final Key? swatchKey;

  bool get _isHeader => variant == MacroLabelVariant.header;

  @override
  Widget build(BuildContext context) {
    final double swatchSize = _isHeader ? 10 : 9;
    final double gap = _isHeader ? 10 : 6;
    final TextStyle textStyle = _isHeader
        ? LiftText.labelLarge
        : LiftText.labelMedium;
    final Color textColor = _isHeader
        ? LiftColors.textPrimary
        : LiftColors.textDim;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          key: swatchKey,
          width: swatchSize,
          height: swatchSize,
          color: kind.color,
        ),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            kind.label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: textStyle.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}
