import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/icons.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Botón de actualización bajo demanda.
/// REGLA ARQUITECTÓNICA: CERO POLLING. El refresco ocurre EXCLUSIVAMENTE
/// cuando el usuario presiona este botón o realiza pull-to-refresh.
class AppRefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final String label;

  const AppRefreshButton({
    super.key,
    required this.onRefresh,
    this.isRefreshing = false,
    this.label = 'Actualizar',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Actualizar datos bajo demanda (Cero polling)',
      child: TextButton(
        onPressed: isRefreshing ? null : onRefresh,
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.blue700,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          shape: const RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedPill,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRefreshing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.blue700),
                ),
              )
            else
              const Icon(
                AppIcons.refresh,
                size: 16,
                color: AppPalette.blue700,
              ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppPalette.blue700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
