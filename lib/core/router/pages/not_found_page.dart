import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design_system/design_system.dart';
import '../route_paths.dart';

/// Pantalla de error 404 para rutas inexistentes o fallos de navegación.
class NotFoundPage extends StatelessWidget {
  final String? path;
  final Exception? error;

  const NotFoundPage({
    super.key,
    this.path,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Página No Encontrada (404)',
          style: AppTypography.headlineMedium,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppPalette.divider, width: 1),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppPalette.blue100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: AppPalette.blue900,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ruta no disponible',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                path != null
                    ? 'No pudimos encontrar la pantalla para: "$path"'
                    : 'La dirección solicitada no existe o no está habilitada.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppPalette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppPalette.divider),
                  ),
                  child: Text(
                    error.toString(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppPalette.textSecondary,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Volver a Ventas',
                icon: CupertinoIcons.arrow_left,
                onPressed: () => context.go(RoutePaths.ventas),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
