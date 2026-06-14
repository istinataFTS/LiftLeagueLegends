import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/themes/app_theme.dart';

/// Pinned bottom dock used by all three log tabs.
///
/// Structure (top → bottom):
///   1. Optional [previewSlot] — e.g. 'This meal' macros row on the Meal tab.
///   2. Gradient primary CTA button (disabled = 40% opacity + non-interactive).
///   3. Optional [statusLine] — e.g. 'Logged ×3 today'.
///
/// The CTA fires [HapticFeedback.mediumImpact] before calling [onSubmit].
/// It scale-animates to 0.98 on press.
class LogActionBar extends StatefulWidget {
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

  @override
  State<LogActionBar> createState() => _LogActionBarState();
}

class _LogActionBarState extends State<LogActionBar> {
  bool _pressed = false;

  bool get _interactive => widget.canSubmit && !widget.isLoading;

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: const Border(top: BorderSide(color: AppTheme.borderDark)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.previewSlot != null) ...<Widget>[
                widget.previewSlot!,
                const SizedBox(height: 8),
              ],
              Opacity(
                opacity: widget.canSubmit ? 1.0 : 0.4,
                child: GestureDetector(
                  onTapDown: _interactive
                      ? (_) => setState(() => _pressed = true)
                      : null,
                  onTapUp: _interactive
                      ? (_) => setState(() => _pressed = false)
                      : null,
                  onTapCancel: _interactive
                      ? () => setState(() => _pressed = false)
                      : null,
                  onTap: _interactive ? _handleTap : null,
                  child: AnimatedScale(
                    scale: _pressed ? 0.98 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Semantics(
                      button: true,
                      enabled: _interactive,
                      label: widget.ctaLabel,
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: widget.canSubmit
                              ? AppTheme.primaryGradient
                              : null,
                          color: widget.canSubmit
                              ? null
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: widget.isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    widget.ctaIcon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.ctaLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.statusLine != null) ...<Widget>[
                const SizedBox(height: 6),
                widget.statusLine!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
