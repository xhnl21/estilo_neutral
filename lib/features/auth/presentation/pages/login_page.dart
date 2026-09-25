import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/access_control_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/auth/biometric_auth_service.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_cubit.dart';

const String _kOrganizacionPorDefecto = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

/// Describe qué botón mostrar y qué va a pasar al tocarlo, para que el
/// usuario tenga claro de antemano si va a elegir una cuenta de Google o
/// solo confirmar con un método ya configurado.
class _AccionLogin {
  final IconData icon;
  final String label;
  final String? caption;

  const _AccionLogin({required this.icon, required this.label, this.caption});
}

/// Pantalla de inicio de sesión de Estilo Neutral.
///
/// La cuenta de Google se elige de forma interactiva la primera vez, y
/// también después de cerrar sesión explícitamente **si la organización no
/// tiene ningún método de Seguridad activo** (ver `MainShell._handleLogout`).
/// En cualquier otro caso (aperturas normales de la app, o después de cerrar
/// sesión teniendo un método activo) la app restaura la sesión de Google en
/// silencio y, si hay un método adicional configurado en Seguridad, muestra
/// su ícono propio (Biométrico, Face ID o 2FA) para que quede claro qué va a
/// pedir antes de tocarlo — sin volver a mostrar el selector de cuentas.
class LoginPage extends StatefulWidget {
  final AuthCubit authCubit;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  LoginPage({
    super.key,
    required this.authCubit,
    required this.sheetsAuth,
    required this.dataService,
    BiometricAuthService? biometricAuthService,
  }) : biometricAuthService = biometricAuthService ?? BiometricAuthService();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// `true` mientras se restaura la sesión en silencio, se abre el selector
  /// de Google, o se verifica el método de seguridad.
  bool _isBusy = true;

  /// Se vuelve `true` en cuanto se descarta la restauración silenciosa (o
  /// falla la verificación de una restauración silenciosa), para recién ahí
  /// mostrar el botón de acción.
  bool _showButton = false;

  String? _errorMessage;

  /// Cuenta ya resuelta (por `signInSilently()` o por selección interactiva)
  /// que está esperando que el usuario confirme el método de seguridad
  /// configurado para su organización. `null` mientras no haya ningún método
  /// pendiente de confirmar (login directo, o todavía no se eligió cuenta).
  GoogleSignInAccount? _pendingAccount;

  /// Método pendiente de confirmar para [_pendingAccount]: 'biometrico',
  /// 'desbloqueo_facial', 'dos_factores', o `null`.
  String? _pendingMetodo;

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

    await _resolveAccount(account);
  }

  Future<void> _handlePrimaryAction() async {
    if (_pendingAccount != null) {
      // Ya se conoce la cuenta y el método pendiente: solo falta confirmarlo.
      await _confirmPendingMetodo();
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

      await _resolveAccount(account);
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

  /// Valida el email, resuelve la organización, y decide si hace falta
  /// mostrar un paso adicional (método de seguridad) antes de completar el
  /// login.
  Future<void> _resolveAccount(GoogleSignInAccount account) async {
    try {
      if (!AccessControlConfig.isEmailAllowed(account.email)) {
        Logger.warning('Intento de login con cuenta no autorizada: ${account.email}');
        await widget.sheetsAuth.signOut();
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _showButton = true;
          _pendingAccount = null;
          _pendingMetodo = null;
          _errorMessage = 'La cuenta ${account.email} no tiene acceso a este sistema. '
              'Contactá al administrador si creés que es un error.';
        });
        return;
      }

      final normalizedEmail = account.email.trim().toLowerCase();
      // La organización ya no se embebe en Usuario: se resuelve a través de la
      // hoja de relación "usuario_organizacion" (1:N organización→usuarios).
      final organizacionId =
          widget.dataService.organizacionIdForUsuario(normalizedEmail) ?? _kOrganizacionPorDefecto;
      widget.dataService.setCurrentOrganizacion(organizacionId);
      widget.dataService.setCurrentUsuario(normalizedEmail);

      // "seguridad" es una preferencia por usuario (no por organización): así,
      // el dispositivo de un usuario no puede apagar el método de otro.
      final metodo = widget.dataService.seguridad.metodoActivo;
      if (metodo == null) {
        // Sin método adicional configurado: login directo.
        _completeLogin(account, organizacionId);
        return;
      }

      // "Desbloqueo facial" solo se muestra como tal si el dispositivo tiene
      // Face ID real disponible. Si no lo tiene (la mayoría de los Android
      // con solo sensor de huella), se resuelve como "Biométrico" — el mismo
      // mecanismo que se va a usar de verdad, sin prometer algo que el
      // equipo no puede cumplir.
      String metodoEfectivo = metodo;
      if (metodo == 'desbloqueo_facial' && !await widget.biometricAuthService.hasFaceId()) {
        metodoEfectivo = 'biometrico';
      }

      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _showButton = true;
        _pendingAccount = account;
        _pendingMetodo = metodoEfectivo;
        _errorMessage = null;
      });
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

  Future<void> _confirmPendingMetodo() async {
    final account = _pendingAccount;
    final metodo = _pendingMetodo;
    if (account == null || metodo == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    bool verificado;
    if (metodo == 'dos_factores') {
      // 2FA todavía no tiene un segundo factor real implementado (ver
      // docs/cumplimiento-normativo.md) — se deja pasar sin bloquear al
      // usuario, pero queda registrado en el log.
      Logger.warning(
        '2FA seleccionado como método de seguridad, pero no hay un segundo factor '
        'implementado todavía; se completó el login sin ese paso.',
      );
      verificado = true;
    } else {
      // 'biometrico' y 'desbloqueo_facial' disparan la misma llamada a
      // local_auth. En Android no hay forma de pedirle a BiometricPrompt
      // "solo rostro" o "solo huella" (setAllowedAuthenticators solo admite
      // BIOMETRIC_STRONG/BIOMETRIC_WEAK, sin distinguir modalidad); el
      // sistema siempre presenta lo que el equipo tenga enrolado. En iOS sí
      // se distingue (Face ID y Touch ID son excluyentes por hardware).
      verificado = await _verifyBiometrics();
    }

    if (!mounted) return;

    if (!verificado) {
      setState(() {
        _isBusy = false;
        _errorMessage = 'No se pudo verificar tu identidad. Tocá el botón para reintentar.';
      });
      return;
    }

    _completeLogin(account, widget.dataService.currentOrganizacionId ?? _kOrganizacionPorDefecto);
  }

  void _completeLogin(GoogleSignInAccount account, String organizacionId) {
    _pendingAccount = null;
    _pendingMetodo = null;
    widget.authCubit.login(email: account.email, organizacionId: organizacionId);
    if (!mounted) return;
    final String? from = GoRouterState.of(context).uri.queryParameters['from'];
    if (from != null && from.isNotEmpty) {
      context.go(from);
    } else {
      context.go(RoutePaths.ventas);
    }
  }

  /// Verifica biometría vía `local_auth`. Si el dispositivo no soporta
  /// biometría (sin hardware o sin nada enrolado), se omite el chequeo en
  /// vez de bloquear el acceso.
  Future<bool> _verifyBiometrics() async {
    final available = await widget.biometricAuthService.isAvailable();
    if (!available) {
      Logger.warning(
        'Método biométrico habilitado para la organización, pero el dispositivo no lo soporta; se omite el chequeo.',
      );
      return true;
    }
    return widget.biometricAuthService.authenticate(
      reason: 'Confirmá tu identidad para completar el inicio de sesión',
    );
  }

  _AccionLogin _accionActual() {
    switch (_pendingMetodo) {
      case 'biometrico':
        return const _AccionLogin(
          icon: CupertinoIcons.hand_raised_fill,
          label: 'Verificar con Biométrico',
          caption: 'Tu organización activó el desbloqueo por huella dactilar. Tocá para confirmarlo e ingresar.',
        );
      case 'desbloqueo_facial':
        return const _AccionLogin(
          icon: CupertinoIcons.person_crop_circle_fill,
          label: 'Verificar con Face ID',
          caption: 'Tu organización activó el desbloqueo facial. Tocá para confirmarlo con Face ID e ingresar.',
        );
      case 'dos_factores':
        return const _AccionLogin(
          icon: CupertinoIcons.lock_rotation,
          label: 'Verificar con 2FA',
          caption: 'Tu organización activó verificación en dos pasos. Tocá para confirmarlo e ingresar.',
        );
      default:
        return const _AccionLogin(
          icon: CupertinoIcons.globe,
          label: 'Continuar con Google',
          caption: 'La primera vez, ingresá con tu cuenta de Google. Las próximas veces vas a poder '
              'confirmar con Biométrico, Face ID o 2FA si tu organización lo activó en Seguridad.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accion = _accionActual();

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
                        child: Icon(
                          _pendingMetodo != null ? accion.icon : CupertinoIcons.lock_shield,
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
                    accion.caption ?? 'Acceso al sistema Estilo Neutral (Google Sheets ORM)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_showButton)
                    AppButton(
                      label: accion.label,
                      icon: accion.icon,
                      isLoading: _isBusy,
                      isFullWidth: true,
                      onPressed: _handlePrimaryAction,
                      semanticHint: accion.caption,
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
