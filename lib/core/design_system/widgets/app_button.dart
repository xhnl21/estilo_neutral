import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Botón primario de acción con fondo blue700, forma píldora y soporte para estado de carga.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveChild = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppPalette.surface),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppPalette.surface),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppPalette.surface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          );

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.blue700,
        foregroundColor: AppPalette.surface,
        disabledBackgroundColor: AppPalette.blue700.withValues(alpha: 0.5),
        minimumSize: const Size(0, 48),
        padding: AppSpacing.pxLg,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppSpacing.roundedPill,
        ),
      ),
      child: effectiveChild,
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
