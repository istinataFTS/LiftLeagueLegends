import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared harness for Log widget tests that need to catch real overflow.
///
/// Every widget test in this slice used to pump at the `flutter_test`
/// default 800x600 desktop-ish surface, and most assertions read declared
/// widget properties (colors, `BoxConstraints` objects) rather than rendered
/// geometry. Both of those hide `RenderFlex`/`Wrap` overflow that is very
/// visible on a real phone: the frames here were designed for 1080x2400 at
/// 3x (360x800 logical), which is materially narrower than 800 logical
/// pixels.
///
/// Call [pumpAtPhoneWidth] instead of `tester.pumpWidget` for any Log test
/// that needs to assert on rendered size or the absence of an overflow
/// error. It sets [WidgetTester.view] to the phone size and registers a
/// teardown that resets it, so the narrowed viewport never leaks into a
/// later test in the same file.
Future<void> pumpAtPhoneWidth(
  WidgetTester tester,
  Widget widget, {
  Size physicalSize = const Size(1080, 2400),
  double devicePixelRatio = 3,
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
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
