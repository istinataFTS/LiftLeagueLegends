import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/themes/lift_theme.dart';

/// Pinned bottom dock used by all three log tabs.
///
/// Structure (top → bottom):
///   1. Optional [previewSlot] — e.g. 'This meal' macros row on the Meal tab.
///   2. Primary CTA button (theme-styled `ElevatedButton`; disabled = square
///      outline instead of fill).
///   3. Optional [statusLine] — e.g. 'Logged ×3 today'.
///
/// The CTA fires [HapticFeedback.mediumImpact] before calling [onSubmit].
class LogActionBar extends StatelessWidget {
  const LogActionBar({
    super.key,
    required this.ctaLabel,
    required this.ctaIcon,
    required this.onSubmit,
    this.previewSlot,
    this.statusLine,
    this.canSubmit = true,
    this.isLoading = false,
  });

  final String ctaLabel;
  final IconData ctaIcon;
  final VoidCallback onSubmit;
  final Widget? previewSlot;
  final Widget? statusLine;
  final bool canSubmit;
  final bool isLoading;

  bool get _interactive => canSubmit && !isLoading;

  void _handleTap() {
    HapticFeedback.mediumImpact();
    onSubmit();
  }

  /// The CTA is on the theme's `elevatedButtonTheme` default (filled
  /// `actionFill`, 52 high, 8px radius, white bold `labelLarge`) whenever
  /// [canSubmit] is true and it isn't loading — `style` stays null so the
  /// theme applies untouched. Two narrow overrides on top of that default:
  ///   - [canSubmit] false: square outline instead of fill (`§4` disabled
  ///     treatment) — this is the one case the theme default can't express.
  ///   - [isLoading] true (and still [canSubmit]): keep the fill while the
  ///     button is momentarily non-interactive, instead of falling back to
  ///     the theme's disabled colours.
  ButtonStyle? _style() {
    if (!canSubmit) {
      return ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: LiftColors.textDisabled,
        disabledForegroundColor: LiftColors.textDisabled,
        side: const BorderSide(
          color: LiftColors.border,
          width: LiftShape.borderWidth,
        ),
      );
    }
    if (isLoading) {
      return ElevatedButton.styleFrom(
        disabledBackgroundColor: LiftColors.actionFill,
        disabledForegroundColor: Colors.white,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: LiftColors.background,
          border: Border(
            top: BorderSide(
              color: LiftColors.rule,
              width: LiftShape.borderWidth,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (previewSlot != null) ...<Widget>[
                previewSlot!,
                const SizedBox(height: 8),
              ],
              Semantics(
                button: true,
                enabled: _interactive,
                label: ctaLabel,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _interactive ? _handleTap : null,
                    style: _style(),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(ctaIcon, size: 16),
                              const SizedBox(width: 8),
                              Text(ctaLabel.toUpperCase()),
                            ],
                          ),
                  ),
                ),
              ),
              if (statusLine != null) ...<Widget>[
                const SizedBox(height: 6),
                Center(
                  child: DefaultTextStyle.merge(
                    key: const ValueKey<String>('log-action-bar-footnote'),
                    style: LiftText.labelMedium.copyWith(
                      color: LiftColors.textDim,
                    ),
                    textAlign: TextAlign.center,
                    child: statusLine!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
