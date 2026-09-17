import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Botón secundario con borde sutil en blue700 y forma píldora.
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;
  final String? semanticHint;

  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.padding,
    this.semanticLabel,
    this.semanticHint,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(
            child: Icon(icon, size: 18, color: AppPalette.blue700),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: AppPalette.blue700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );

    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      hint: semanticHint,
      excludeSemantics: true,
      onTap: onPressed,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.blue700,
          side: const BorderSide(color: AppPalette.blue700, width: 1),
          minimumSize: const Size(0, 48),
          padding: padding ?? AppSpacing.pxLg,
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedPill,
          ),
        ),
        child: child,
      ),
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}
