import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../shared/shared.dart';

/// Vista de configuración de métodos de autenticación (hoja: seguridad)
/// Biométrico, desbloqueo facial y verificación en dos pasos (2FA).
class SeguridadPage extends StatelessWidget {
  final SheetsDataService dataService;

  const SeguridadPage({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dataService,
      builder: (context, _) {
        final seguridad = dataService.seguridad;

        return AppScaffold(
          title: 'Seguridad',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'seguridad',
            userFriendlyText: 'Métodos de autenticación',
          ),
          actions: const [
            ExcludeSemantics(
              child: Icon(CupertinoIcons.lock_shield, color: AppPalette.blue700),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      _SeguridadToggleRow(
                        label: 'Biométrico',
                        hint: 'Usar huella dactilar para iniciar sesión',
                        value: seguridad.biometrico,
                        onChanged: (_) => dataService.toggleBiometrico(),
                      ),
                      const Divider(height: 1, color: AppPalette.divider),
                      _SeguridadToggleRow(
                        label: 'Desbloqueo facial',
                        hint: 'Usar reconocimiento facial para iniciar sesión',
                        value: seguridad.desbloqueoFacial,
                        onChanged: (_) => dataService.toggleDesbloqueoFacial(),
                      ),
                      const Divider(height: 1, color: AppPalette.divider),
                      _SeguridadToggleRow(
                        label: '2FA',
                        hint: 'Solicitar un segundo factor de verificación al iniciar sesión',
                        value: seguridad.dosFactores,
                        onChanged: (_) => dataService.toggleDosFactores(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeguridadToggleRow extends StatelessWidget {
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SeguridadToggleRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: hint,
      child: SwitchListTile(
        title: Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        value: value,
        activeThumbColor: AppPalette.success,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      ),
    );
  }
}
