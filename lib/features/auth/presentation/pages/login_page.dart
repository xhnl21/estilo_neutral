import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/access_control_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/logger.dart';
import '../../../../models/models.dart';
import '../../../../shared/auth/biometric_auth_service.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_notifier.dart';

/// Pantalla de inicio de sesión de Estilo Neutral.
///
/// La cuenta de Google solo se elige de forma interactiva la primera vez (o
/// después de cerrar sesión explícitamente). En aperturas siguientes, la app
/// restaura la sesión de Google en silencio y, si la organización tiene
/// activado el desbloqueo biométrico, pide huella/Face ID en su lugar.
class LoginPage extends StatefulWidget {
  final AuthNotifier authNotifier;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  LoginPage({
    super.key,
    required this.authNotifier,
    required this.sheetsAuth,
    required this.dataService,
    BiometricAuthService? biometricAuthService,
  }) : biometricAuthService = biometricAuthService ?? BiometricAuthService();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// `true` mientras se restaura la sesión en silencio, se abre el selector
  /// de Google, o se verifica biometría.
  bool _isBusy = true;

  /// Se vuelve `true` en cuanto se descarta la restauración silenciosa (o
  /// falla la biometría de una restauración silenciosa), para recién ahí
  /// mostrar el botón de acción.
  bool _showButton = false;

  String? _errorMessage;

  /// Cuenta ya resuelta por `signInSilently()` cuya única traba fue un
  /// intento de biometría fallido/cancelado. Si existe, el botón reintenta
  /// solo la biometría en vez de volver a abrir el selector de Google.
  GoogleSignInAccount? _pendingSilentAccount;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final account = await widget.sheetsAuth.signInSilently();
    if (!mounted) return;

    if (account == null) {
      // No hay sesión previa (primera vez, o se cerró sesión explícitamente).
      setState(() {
        _isBusy = false;
        _showButton = true;
      });
      return;
    }

    await _finishSignIn(account, isSilent: true);
  }

  Future<void> _handleGoogleSignIn() async {
    if (_pendingSilentAccount != null) {
      // Solo falló la biometría de una sesión ya restaurada: reintentar sin
      // volver a mostrar el selector de cuentas de Google.
      await _finishSignIn(_pendingSilentAccount!, isSilent: true);
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final account = await widget.sheetsAuth.signIn();
      if (!mounted) return;

      if (account == null) {
        // El usuario canceló el selector de cuentas de Google.
        setState(() => _isBusy = false);
        return;
      }

      await _finishSignIn(account, isSilent: false);
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al iniciar sesión con Google',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = 'No se pudo iniciar sesión con Google. Intenta nuevamente.';
      });
    }
  }

  Future<void> _finishSignIn(GoogleSignInAccount account, {required bool isSilent}) async {
    try {
      if (!AccessControlConfig.isEmailAllowed(account.email)) {
        Logger.warning('Intento de login con cuenta no autorizada: ${account.email}');
        await widget.sheetsAuth.signOut();
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _showButton = true;
          _pendingSilentAccount = null;
          _errorMessage = 'La cuenta ${account.email} no tiene acceso a este sistema. '
              'Contactá al administrador si creés que es un error.';
        });
        return;
      }

      final normalizedEmail = account.email.trim().toLowerCase();
      final usuario = widget.dataService.usuarios.firstWhere(
        (u) => u.email == normalizedEmail,
        orElse: () => Usuario(email: normalizedEmail, organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768'),
      );
      widget.dataService.setCurrentOrganizacion(usuario.organizacionId);

      if (widget.dataService.seguridad.biometrico) {
        final biometricOk = await _verifyBiometrics();
        if (!mounted) return;
        if (!biometricOk) {
          widget.dataService.setCurrentOrganizacion(null);
          if (isSilent) {
            // No cerramos la sesión de Google: la cuenta ya está restaurada,
            // solo falló el paso biométrico. Se puede reintentar sin volver
            // a elegir cuenta.
            setState(() {
              _isBusy = false;
              _showButton = true;
              _pendingSilentAccount = account;
              _errorMessage = 'No se pudo verificar tu identidad. Tocá el botón para reintentar.';
            });
          } else {
            await widget.sheetsAuth.signOut();
            if (!mounted) return;
            setState(() {
              _isBusy = false;
              _errorMessage = 'No se pudo verificar tu identidad con biometría. Intenta nuevamente.';
            });
          }
          return;
        }
      }

      _pendingSilentAccount = null;
      widget.authNotifier.login(email: account.email, organizacionId: usuario.organizacionId);
      if (!mounted) return;
      final String? from = GoRouterState.of(context).uri.queryParameters['from'];
      if (from != null && from.isNotEmpty) {
        context.go(from);
      } else {
        context.go(RoutePaths.ventas);
      }
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al restaurar la sesión',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _showButton = true;
        _errorMessage = 'No se pudo iniciar sesión. Intenta nuevamente.';
      });
    }
  }

  /// Verifica biometría cuando está habilitada en la hoja `seguridad`.
  /// Si el dispositivo no soporta biometría (sin hardware o sin nada
  /// enrolado), se omite el chequeo en vez de bloquear el acceso.
  Future<bool> _verifyBiometrics() async {
    final available = await widget.biometricAuthService.isAvailable();
    if (!available) {
      Logger.warning(
        'Biometría habilitada para la organización, pero el dispositivo no la soporta; se omite el chequeo.',
      );
      return true;
    }
    return widget.biometricAuthService.authenticate(
      reason: 'Confirmá tu identidad con biometría para completar el inicio de sesión',
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _pendingSilentAccount != null ? 'Reintentar verificación' : 'Continuar con Google';
    final buttonIcon = _pendingSilentAccount != null ? CupertinoIcons.arrow_clockwise : CupertinoIcons.globe;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppPalette.blue100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.lock_shield,
                          color: AppPalette.blue900,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      'Iniciar Sesión',
                      style: AppTypography.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Acceso al sistema Estilo Neutral (Google Sheets ORM)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_showButton)
                    AppButton(
                      label: buttonLabel,
                      icon: buttonIcon,
                      isLoading: _isBusy,
                      isFullWidth: true,
                      onPressed: _handleGoogleSignIn,
                      semanticHint: _pendingSilentAccount != null
                          ? 'Vuelve a pedir la verificación biométrica'
                          : 'Abre el selector de cuentas de Google para iniciar sesión',
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppPalette.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
