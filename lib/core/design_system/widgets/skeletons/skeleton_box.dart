import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';

/// Bloque rectangular / redondeado para simular elementos visuales.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? AppSpacing.roundedSm),
      ),
    );
  }
}
