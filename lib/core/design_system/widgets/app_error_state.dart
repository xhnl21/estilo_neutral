import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/icons.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'app_button.dart';

/// Estado de error minimalista con icono Cupertino y botón de reintento bajo demanda.
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pXl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              AppIcons.error,
              size: AppIcons.xl,
              color: AppPalette.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ocurrió un error',
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(color: AppPalette.error),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: retryLabel,
                icon: AppIcons.refresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
