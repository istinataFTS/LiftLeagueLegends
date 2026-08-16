import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared harness for widget tests that need to catch real overflow.
///
/// Widget tests pump at the `flutter_test` default 800x600 desktop-ish
/// surface, and most assertions read declared widget properties (colors,
/// `BoxConstraints` objects) rather than rendered geometry. Both of those
/// hide `RenderFlex`/`Wrap` overflow that is very visible on a real phone.
///
/// The default surface here is 1080x2400 at 3x — 360x800 logical. That is
/// **not** the size the frames were designed at: the design export is
/// 1176x2538, roughly 392x846 logical at 3x. 360 is chosen deliberately as
/// a floor narrower than the target, because a layout that does not
/// overflow at 360 cannot overflow at 392. Testing narrow is the
/// conservative direction for overflow, so the default must stay 360 even
/// though it is not the design width.
///
/// Call [pumpAtPhoneWidth] instead of `tester.pumpWidget` for any test that
/// needs to assert on rendered size or the absence of an overflow error. It
/// sets [WidgetTester.view] to the phone size and registers a teardown that
/// resets it, so the narrowed viewport never leaks into a later test in the
/// same file.
/// Pass `settle: false` when the subject holds an indefinite animation — a
/// `CircularProgressIndicator` never stops, so `pumpAndSettle` would time out
/// rather than assert anything. A single `pump` is enough to lay the tree out.
Future<void> pumpAtPhoneWidth(
  WidgetTester tester,
  Widget widget, {
  Size physicalSize = const Size(1080, 2400),
  double devicePixelRatio = 3,
  bool settle = true,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Asserts that pumping did not record a `FlutterError` (the way a
/// `RenderFlex`/`Wrap` overflow surfaces in tests) — a `RenderFlex` overflow
/// paints an error stripe but only fails a test if something actually checks
/// `tester.takeException()`.
void expectNoOverflow(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'expected no overflow/render exception at phone width',
  );
}
