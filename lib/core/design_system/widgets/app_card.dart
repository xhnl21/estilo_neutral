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
  final String? semanticLabel;
  final String? semanticHint;
  final bool mergeSemantics;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.pLg,
    this.onTap,
    this.backgroundColor,
    this.hasShadow = false,
    this.semanticLabel,
    this.semanticHint,
    this.mergeSemantics = false,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppPalette.surface,
      borderRadius: AppSpacing.roundedMd,
      border: Border.all(color: AppPalette.border, width: 1),
      boxShadow: hasShadow ? AppSpacing.shadowSoft : AppSpacing.shadowNone,
    );

    Widget result;
    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: Semantics(
          container: true,
          button: true,
          enabled: true,
          label: semanticLabel,
          hint: semanticHint,
          excludeSemantics: semanticLabel != null,
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
        ),
      );
    } else if (semanticLabel != null) {
      result = Semantics(
        container: true,
        label: semanticLabel,
        hint: semanticHint,
        excludeSemantics: true,
        child: Container(
          decoration: decoration,
          padding: padding,
          child: child,
        ),
      );
    } else {
      result = Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }

    if (mergeSemantics) {
      return MergeSemantics(child: result);
    }
    return result;
  }
}
