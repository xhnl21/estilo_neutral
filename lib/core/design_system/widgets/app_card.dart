import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';

/// Tarjeta minimalista con superficie blanco azulado, borde sutil y padding modular.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool hasShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.pLg,
    this.onTap,
    this.backgroundColor,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppPalette.surface,
      borderRadius: AppSpacing.roundedMd,
      border: Border.all(color: AppPalette.border, width: 1),
      boxShadow: hasShadow ? AppSpacing.shadowSoft : AppSpacing.shadowNone,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.roundedMd,
          child: Ink(
            decoration: decoration,
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );
  }
}
