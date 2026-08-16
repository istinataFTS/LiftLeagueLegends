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
          child: Container(
            key: HomePageKeys.bodyVisualPanelKey,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: LiftColors.surface,
              border: Border.fromBorderSide(
                BorderSide(
                  color: LiftColors.border,
                  width: LiftShape.borderWidth,
                ),
              ),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.62,
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
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Text(
              isFront ? 'FRONT' : 'BACK',
              style: LiftText.labelLarge.copyWith(
                color: LiftColors.textSecondary,
              ),
            ),
            const Spacer(),
            // `LiftTheme.dark()`'s elevatedButtonTheme sets minimumSize to
            // `Size.fromHeight(52)`, whose width component is
            // `double.infinity` (it is designed for full-width CTAs like
            // `LogActionBar`'s, which sits in a tight-width parent). A bare
            // `Row` child gets unbounded main-axis constraints, so pairing
            // the two forces a tight-infinite width and crashes. Wrapping in
            // `IntrinsicWidth` gives the button a bounded, content-sized
            // width to resolve against without adding a `style:` override.
            IntrinsicWidth(
              child: ElevatedButton(
                key: HomePageKeys.bodyVisualFlipButtonKey,
                onPressed: _flip,
                child: Text(isFront ? 'SHOW BACK' : 'SHOW FRONT'),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(baseAssetPath, fit: BoxFit.contain),
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
