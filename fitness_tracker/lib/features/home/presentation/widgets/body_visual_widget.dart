import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
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
    final String label = isFront ? 'Front' : 'Back';
    final String asset = isFront ? _frontBaseAsset : _backBaseAsset;
    final List<HomeBodyOverlayViewData> layers = isFront
        ? widget.viewData.frontLayers
        : widget.viewData.backLayers;

    return Container(
      key: HomePageKeys.bodyVisualKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Muscle map',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                widget.viewData.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AspectRatio(
                aspectRatio: 0.62,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _BodyFigure(
                    key: ValueKey<BodySide>(_side),
                    label: label,
                    baseAssetPath: asset,
                    layers: layers,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: _FlipControl(currentSide: _side, onFlip: _flip),
          ),
        ],
      ),
    );
  }
}

class _BodyFigure extends StatelessWidget {
  const _BodyFigure({
    super.key,
    required this.label,
    required this.baseAssetPath,
    required this.layers,
  });

  final String label;
  final String baseAssetPath;
  final List<HomeBodyOverlayViewData> layers;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(
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
          ),
        ),
      ],
    );
  }
}

class _FlipControl extends StatelessWidget {
  const _FlipControl({required this.currentSide, required this.onFlip});

  final BodySide currentSide;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final String nextLabel = currentSide == BodySide.front
        ? 'Show back'
        : 'Show front';

    return TextButton.icon(
      key: HomePageKeys.bodyVisualFlipButtonKey,
      onPressed: onFlip,
      icon: const Icon(Icons.cached, size: 18),
      label: Text(nextLabel),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
      ),
    );
  }
}
