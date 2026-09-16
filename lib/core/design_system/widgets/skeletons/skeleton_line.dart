import 'package:flutter/material.dart';
import '../../tokens/spacing.dart';

/// Línea placeholder simulando texto con bordes redondeados y altura tipográfica.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14.0,
    this.borderRadius,
    this.color,
  });

  /// Línea simulando un título prominente (~20px de altura)
  const SkeletonLine.title({
    super.key,
    this.width = 160.0,
    this.borderRadius,
    this.color,
  }) : height = 20.0;

  /// Línea simulando un subtítulo o etiqueta (~16px de altura)
  const SkeletonLine.subtitle({
    super.key,
    this.width = 120.0,
    this.borderRadius,
    this.color,
  }) : height = 16.0;

  /// Línea simulando cuerpo de texto (~14px de altura)
  const SkeletonLine.body({
    super.key,
    this.width,
    this.borderRadius,
    this.color,
  }) : height = 14.0;

  /// Línea simulando texto pequeño / metadatos (~10px de altura)
  const SkeletonLine.caption({
    super.key,
    this.width = 80.0,
    this.borderRadius,
    this.color,
  }) : height = 10.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        borderRadius: borderRadius ?? AppSpacing.roundedSm,
      ),
    );
  }
}
