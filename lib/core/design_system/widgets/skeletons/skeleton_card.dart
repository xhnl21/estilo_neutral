import 'package:flutter/material.dart';
import '../../tokens/colors.dart';
import '../../tokens/spacing.dart';

/// Contenedor de tarjeta para skeleton loaders, consistente con [AppCard].
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.pMd,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppPalette.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppPalette.border, width: 1),
      ),
      padding: padding,
      child: child,
    );
  }
}
