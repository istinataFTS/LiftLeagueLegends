import 'package:flutter/foundation.dart';

/// Shared signal: is an in-layout numeric keypad (LogNumericKeypad) currently
/// docked at the bottom of a Log tab? The global VoiceFab watches this and
/// hides itself while a keypad is open, so the mic button can't overlap the
/// keypad's confirm / Done key. Log tabs call [show] when they swap their
/// dock for the keypad and [hide] on submit / cancel / dispose. App-lived
/// singleton; lives in `core/` so both `features/log/` and `features/voice/`
/// can import it without triggering the `cross-feature-presentation-import`
/// convention rule.
class KeypadVisibilityController {
  final ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);
  void show() => isOpen.value = true;
  void hide() => isOpen.value = false;
}
