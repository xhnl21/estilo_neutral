import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../application/auth_notifier.dart';

/// Pantalla de bienvenida / inducción inicial.
class OnboardingPage extends StatelessWidget {
  final AuthNotifier authNotifier;

  const OnboardingPage({super.key, required this.authNotifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppPalette.blue100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.sparkles,
                      color: AppPalette.blue900,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  headingLevel: 1,
                  child: Text(
                    'Bienvenido a Estilo Neutral',
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Gestión operativa empresarial sincronizada con Google Sheets en tiempo real con arquitectura bajo demanda y cero polling.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        icon: CupertinoIcons.cart,
                        title: 'Operaciones Comerciales',
                        description: 'Gestión de clientes, inventario y registro de ventas.',
                      ),
                      const Divider(color: AppPalette.divider),
                      _buildFeatureItem(
                        icon: CupertinoIcons.money_dollar_circle,
                        title: 'Tesorería y Finanzas',
                        description: 'Control de compras de divisas y resumen diario.',
                      ),
                      const Divider(color: AppPalette.divider),
                      _buildFeatureItem(
                        icon: CupertinoIcons.shield_lefthalf_fill,
                        title: 'Auditoría y Calidad ISO',
                        description: 'Trazabilidad con audit log, cuarentena y checklist.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Comenzar a Trabajar',
                  icon: CupertinoIcons.check_mark,
                  onPressed: () {
                    authNotifier.completeOnboarding();
                    context.go(RoutePaths.ventas);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: AppPalette.blue700, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
