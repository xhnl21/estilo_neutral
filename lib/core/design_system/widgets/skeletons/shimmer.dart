import 'package:flutter/material.dart';
import '../../tokens/colors.dart';

/// Shimmer de alto rendimiento para skeletons progresivos.
/// Utiliza [AnimationController] + [ShaderMask] con gradiente lineal
/// aislado en un [RepaintBoundary] para sostener 60 fps continuos sin jank.
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;
  final bool enabled;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  /// Shimmer con tintado sutil en la paleta azul del Design System
  const AppShimmer.subtleBlue({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFD6E2F0),
    this.highlightColor = AppPalette.surface,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                colors: [
                  widget.baseColor,
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                  widget.baseColor,
                ],
                transform: _SlidingGradientTransform(slidePercent: progress),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Desplaza el gradiente suavemente de izquierda (-bounds.width) a derecha (+bounds.width)
    final translation = bounds.width * 2 * (slidePercent - 0.5);
    return Matrix4.translationValues(translation, 0.0, 0.0);
  }
}
