import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../core/utils/logger.dart';
import '../../shared/auth/biometric_auth_service.dart';
import '../../shared/shared.dart';

/// Vista de configuración de métodos de autenticación (hoja: seguridad)
/// Biométrico, desbloqueo facial y verificación en dos pasos (2FA).
///
/// Los tres métodos son mutuamente excluyentes: solo uno puede estar activo
/// a la vez (o ninguno), por eso se presentan como un grupo de selección
/// única en vez de switches independientes.
///
/// "Biométrico" y "Desbloqueo facial" solo se muestran como opciones si el
/// dispositivo actual realmente los soporta — así se evita la confusión de
/// elegir un método que el equipo no puede cumplir. Si el método activo de
/// la organización deja de ser compatible con el dispositivo desde el que se
/// abre esta vista (por ejemplo, "Desbloqueo facial" activado desde un
/// iPhone y esta vista se abre desde un Android sin cámara de profundidad),
/// se corrige automáticamente a "Ninguno" y se persiste el cambio en la hoja
/// `seguridad`.
class SeguridadPage extends StatefulWidget {
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  SeguridadPage({
    super.key,
    required this.dataService,
    BiometricAuthService? biometricAuthService,
  }) : biometricAuthService = biometricAuthService ?? BiometricAuthService();

  @override
  State<SeguridadPage> createState() => _SeguridadPageState();
}

class _SeguridadPageState extends State<SeguridadPage> {
  bool _cargandoCapacidades = true;
  bool _biometricoDisponible = false;
  bool _faceIdDisponible = false;

  @override
  void initState() {
    super.initState();
    _detectarCapacidades();
  }

  Future<void> _detectarCapacidades() async {
    final biometrico = await widget.biometricAuthService.isAvailable();
    final faceId = biometrico ? await widget.biometricAuthService.hasFaceId() : false;
    if (!mounted) return;
    setState(() {
      _biometricoDisponible = biometrico;
      _faceIdDisponible = faceId;
      _cargandoCapacidades = false;
    });
    _corregirMetodoIncompatible();
  }

  /// Si el método activo de la organización no es compatible con este
  /// dispositivo (por ejemplo "Desbloqueo facial" abierto desde un equipo sin
  /// reconocimiento facial real), lo resetea a "Ninguno" y persiste el
  /// cambio en la hoja `seguridad` — no se deja seleccionada una opción que
  /// este dispositivo no puede cumplir.
  void _corregirMetodoIncompatible() {
    final metodoActivo = widget.dataService.seguridad.metodoActivo;
    final esIncompatible = (metodoActivo == 'biometrico' && !_biometricoDisponible) ||
        (metodoActivo == 'desbloqueo_facial' && !_faceIdDisponible);
    if (!esIncompatible) return;

    Logger.warning(
      'Método de seguridad "$metodoActivo" no es compatible con este dispositivo; '
      'se restablece a "Ninguno".',
    );
    widget.dataService.setMetodoSeguridad(null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dataService,
      builder: (context, _) {
        final metodoActivo = widget.dataService.seguridad.metodoActivo;

        return AppScaffold(
          title: 'Seguridad',
          subtitle: EnvironmentConfig.formatSubtitle(
            sheetName: 'seguridad',
            userFriendlyText: 'Método de autenticación adicional',
          ),
          actions: const [
            ExcludeSemantics(
              child: Icon(CupertinoIcons.lock_shield, color: AppPalette.blue700),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Elegí un único método adicional para iniciar sesión, además de tu cuenta de Google.',
                  style: AppTypography.bodyMedium.copyWith(color: AppPalette.textSecondary),
                ),
              ),
              if (_cargandoCapacidades)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    type: MaterialType.transparency,
                    child: RadioGroup<String?>(
                      groupValue: metodoActivo,
                      onChanged: widget.dataService.setMetodoSeguridad,
                      child: Column(
                        children: [
                          const _SeguridadMetodoRow(
                            label: 'Ninguno',
                            hint: 'Solo pide la cuenta de Google al iniciar sesión',
                            value: null,
                          ),
                          if (_biometricoDisponible) ...const [
                            Divider(height: 1, color: AppPalette.divider),
                            _SeguridadMetodoRow(
                              label: 'Biométrico',
                              hint: 'Pide huella dactilar al iniciar sesión',
                              value: 'biometrico',
                            ),
                          ],
                          if (_faceIdDisponible) ...const [
                            Divider(height: 1, color: AppPalette.divider),
                            _SeguridadMetodoRow(
                              label: 'Desbloqueo facial',
                              hint: 'Pide reconocimiento facial al iniciar sesión',
                              value: 'desbloqueo_facial',
                            ),
                          ],
                          const Divider(height: 1, color: AppPalette.divider),
                          const _SeguridadMetodoRow(
                            label: '2FA',
                            hint: 'Pide un segundo factor de verificación al iniciar sesión',
                            value: 'dos_factores',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!_cargandoCapacidades && !_biometricoDisponible)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Este dispositivo no tiene huella ni reconocimiento facial configurado, '
                    'por eso no se muestran esas opciones acá.',
                    style: AppTypography.labelSmall.copyWith(color: AppPalette.textSecondary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SeguridadMetodoRow extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;

  const _SeguridadMetodoRow({
    required this.label,
    required this.hint,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      hint: hint,
      child: RadioListTile<String?>(
        title: Text(label, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        value: value,
        activeColor: AppPalette.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      ),
    );
  }
}
