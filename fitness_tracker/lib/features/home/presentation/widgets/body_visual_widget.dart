import 'package:flutter/material.dart';

import '../../../../core/themes/lift_theme.dart';
import '../home_page_keys.dart';
import '../models/home_view_data.dart';

/// Which face of the 2D body model is currently shown.
///
/// Kept in widget state rather than view data because the flip is a pure UI
/// concern (no domain meaning) — the bloc/mapper continues to publish both
/// [HomeBodyVisualViewData.frontLayers] and [HomeBodyVisualViewData.backLayers]
/// every frame and this widget picks one to render.
enum BodySide { front, back }

class BodyVisualWidget extends StatefulWidget {
  const BodyVisualWidget({
    super.key,
    required this.viewData,
    this.initialSide = BodySide.front,
  });

  final HomeBodyVisualViewData viewData;
  final BodySide initialSide;

  @override
  State<BodyVisualWidget> createState() => _BodyVisualWidgetState();
}

class _BodyVisualWidgetState extends State<BodyVisualWidget> {
  static const String _frontBaseAsset = 'assets/images/body/FrontLook.png';
  static const String _backBaseAsset = 'assets/images/body/BackLook.png';

  /// Every body raster — both faces and all 26 overlays — shares this canvas.
  static const Size _canvas = Size(440, 956);

  /// The figure's opaque bounds inside [_canvas], the union of the two faces:
  /// `FrontLook.png` inks (48,195)-(386,851) and `BackLook.png` (47,194)-(387,
  /// 848) since the realignment in #212. Roughly a third of the canvas is
  /// transparent margin, so fitting the *canvas* into the available box —
  /// which is what a plain `BoxFit.contain` does — spends a third of the
  /// screen's tallest dimension on nothing and renders the figure about 45%
  /// smaller than the space allows. Both faces are cropped to the same rect
  /// so the flip does not shift the model.
  static const Rect _figureInk = Rect.fromLTRB(47, 194, 387, 851);

  late BodySide _side = widget.initialSide;

  void _flip() {
    setState(() {
      _side = _side == BodySide.front ? BodySide.back : BodySide.front;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isFront = _side == BodySide.front;
    final String asset = isFront ? _frontBaseAsset : _backBaseAsset;
    final List<HomeBodyOverlayViewData> layers = isFront
        ? widget.viewData.frontLayers
        : widget.viewData.backLayers;

    return Column(
      key: HomePageKeys.bodyVisualKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          // No frame and no fill: the map is the screen on Home, and a
          // bordered panel around it drew a box the figure then had to
          // letterbox inside. The two-tone ground shows straight through.
          child: SizedBox(
            key: HomePageKeys.bodyVisualPanelKey,
            width: double.infinity,
            child: Center(
              child: AspectRatio(
                // The *figure's* aspect, not the canvas's. See [_figureInk].
                aspectRatio: _figureInk.width / _figureInk.height,
                child: ClipRect(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          // Scale the whole 440x956 art canvas up until its
                          // ink box fills this box, then slide the canvas so
                          // that box starts at the origin. Uniform in both
                          // axes because the `AspectRatio` above already
                          // matches the ink box's proportions.
                          final double scale =
                              constraints.maxWidth / _figureInk.width;
                          return OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 0,
                            maxWidth: double.infinity,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: Transform.translate(
                              offset: Offset(
                                -_figureInk.left * scale,
                                -_figureInk.top * scale,
                              ),
                              child: SizedBox(
                                width: _canvas.width * scale,
                                height: _canvas.height * scale,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  child: _BodyFigure(
                                    key: ValueKey<BodySide>(_side),
                                    baseAssetPath: asset,
                                    layers: layers,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Text(
              isFront ? 'FRONT' : 'BACK',
              style: LiftText.labelLarge.copyWith(
                color: LiftColors.textSecondary,
              ),
            ),
            const Spacer(),
            // Deliberately styled off-theme. `LiftTheme.dark()`'s
            // elevatedButtonTheme sets `minimumSize: Size.fromHeight(52)` —
            // a full-width CTA shape, designed for `LogActionBar`, whose
            // width component is `double.infinity` (so a bare `Row` child
            // pairing the two forces a tight-infinite width and crashes).
            //
            // At 52dp the control is also the reason the figure sits high on
            // the page: the chrome under the map ran 84dp against the ~55dp
            // above it, so the model's feet cleared the intake rule by half
            // again what its head cleared the header rule by. This is a
            // secondary toggle, not a CTA — at ~26dp the two margins match
            // and the figure reads as centred between the rules.
            ElevatedButton(
              key: HomePageKeys.bodyVisualFlipButtonKey,
              onPressed: _flip,
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: LiftText.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(isFront ? 'SHOW BACK' : 'SHOW FRONT'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({
    super.key,
    required this.baseAssetPath,
    required this.layers,
  });

  final String baseAssetPath;
  final List<HomeBodyOverlayViewData> layers;

  /// `bodyBase` divided by the art's own grey: 0x55 * 255 / 195 = 0x6F. Under
  /// `BlendMode.modulate` (a component-wise multiply) that lands the art's
  /// flat grey-195 body on `LiftColors.bodyBase` while keeping its internal
  /// shading and outline highlights proportional — a `srcATop` tint would
  /// flatten the figure to a silhouette and throw the anatomy away.
  static const Color _baseTint = Color(0xFF6F7F8F);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          baseAssetPath,
          fit: BoxFit.contain,
          color: _baseTint,
          colorBlendMode: BlendMode.modulate,
        ),
        for (final HomeBodyOverlayViewData layer in layers)
          Opacity(
            opacity: layer.opacity,
            child: Image.asset(
              layer.assetPath,
              fit: BoxFit.contain,
              color: layer.color,
              colorBlendMode: BlendMode.srcATop,
            ),
          ),
      ],
    );
  }
}
