import 'package:flutter/material.dart';

/// Círculo placeholder para avatares, fotos redondas o botones flotantes.
class SkeletonCircle extends StatelessWidget {
  final double radius;
  final Color? color;

  const SkeletonCircle({
    super.key,
    this.radius = 20.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
    );
  }
}
