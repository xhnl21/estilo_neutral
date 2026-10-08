import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/auth/biometric_auth_service.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_cubit.dart';
import 'login_state.dart';

/// Cubit de la pantalla de inicio de sesión: restauración silenciosa de la
/// sesión de Google, control de acceso (hoja "usuarios" + membresía, ver
/// [SheetsDataService.resolverAcceso]) y confirmación del método de
/// seguridad configurado.
class LoginCubit extends Cubit<LoginState> {
  final AuthCubit authCubit;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;
  final BiometricAuthService biometricAuthService;

  /// Cuenta ya elegida que espera la confirmación del método de seguridad.
  GoogleSignInAccount? _cuentaPendiente;

  LoginCubit({
    required this.authCubit,
    required this.sheetsAuth,
    required this.dataService,
    required this.biometricAuthService,
  }) : super(LoginState(errorMessage: authCubit.state.motivoCierreSesion));

  /// Intenta restaurar la sesión de Google sin mostrar el selector.
  Future<void> restaurarSesion() async {
    emit(state.copyWith(status: LoginStatus.restaurando));
    final account = await sheetsAuth.signInSilently();
    if (isClosed) return;
    if (account == null) {
      // Primera vez, o se cerró sesión explícitamente.
      emit(state.copyWith(status: LoginStatus.listo));
      return;
    }
    await _resolverCuenta(account);
  }

  /// Acción del botón principal: confirma el método pendiente o abre el
  /// selector de cuentas de Google.
  Future<void> accionPrincipal() async {
    if (state.isBusy) return;
    if (_cuentaPendiente != null) {
      await _confirmarMetodo();
      return;
    }

    emit(state.copyWith(status: LoginStatus.procesando, clearError: true));
    try {
      final account = await sheetsAuth.signIn();
      if (isClosed) return;
      if (account == null) {
        // El usuario canceló el selector de cuentas de Google.
        emit(state.copyWith(status: LoginStatus.listo));
        return;
      }
      await _resolverCuenta(account);
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al iniciar sesión con Google',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: LoginStatus.listo,
        errorMessage: 'No se pudo iniciar sesión con Google. Intenta nuevamente.',
      ));
    }
  }

  /// Verifica el acceso, resuelve la organización y decide si hace falta
  /// confirmar un método de seguridad antes de completar el login.
  Future<void> _resolverCuenta(GoogleSignInAccount account) async {
    try {
      // El acceso lo deciden "usuarios" + "usuario_organizacion": hay que
      // esperar a que esos datos hayan cargado.
      await dataService.esperarCargaInicial();
      final email = account.email.trim().toLowerCase();
      var acceso = dataService.resolverAcceso(email);
      if (acceso.organizacionId == null) {
        // La copia local puede estar vieja: p. ej. la cuenta fue inactivada
        // (y expulsada) y después reactivada sin reiniciar la app. Antes de
        // rechazar, se releen las hojas de acceso del servidor.
        await dataService.releerAcceso();
        if (isClosed) return;
        acceso = dataService.resolverAcceso(email);
      }
      final organizacionId = acceso.organizacionId;
      if (organizacionId == null) {
        Logger.warning('Login rechazado para ${account.email}: ${acceso.motivo}');
        await sheetsAuth.signOut();
        if (isClosed) return;
        _cuentaPendiente = null;
        emit(state.copyWith(
          status: LoginStatus.listo,
          clearMetodoPendiente: true,
          errorMessage: '${acceso.motivo} Contactá al administrador si creés que es un error.',
        ));
        return;
      }

      dataService.setCurrentOrganizacion(organizacionId);
      dataService.setCurrentUsuario(email);

      // "seguridad" es una preferencia por usuario (no por organización).
      final metodo = dataService.seguridad.metodoActivo;
      if (metodo == null) {
        _completarLogin(account, organizacionId);
        return;
      }

      // "Desbloqueo facial" solo se ofrece como tal si el dispositivo tiene
      // Face ID; si no (la mayoría de los Android), se resuelve como
      // "Biométrico", que es el mecanismo que se va a usar de verdad.
      var metodoEfectivo = metodo;
      if (metodo == 'desbloqueo_facial' && !await biometricAuthService.hasFaceId()) {
        metodoEfectivo = 'biometrico';
      }
      if (isClosed) return;
      _cuentaPendiente = account;
      emit(state.copyWith(
        status: LoginStatus.listo,
        metodoPendiente: metodoEfectivo,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al restaurar la sesión',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: LoginStatus.listo,
        errorMessage: 'No se pudo iniciar sesión. Intenta nuevamente.',
      ));
    }
  }

  Future<void> _confirmarMetodo() async {
    final account = _cuentaPendiente;
    final metodo = state.metodoPendiente;
    if (account == null || metodo == null) return;

    emit(state.copyWith(status: LoginStatus.procesando, clearError: true));

    final bool verificado;
    if (metodo == 'dos_factores') {
      // 2FA todavía no tiene un segundo factor real (ver
      // docs/cumplimiento-normativo.md): se deja pasar, pero queda en el log.
      Logger.warning(
        '2FA seleccionado como método de seguridad, pero no hay un segundo factor '
        'implementado todavía; se completó el login sin ese paso.',
      );
      verificado = true;
    } else {
      // 'biometrico' y 'desbloqueo_facial' usan la misma llamada a local_auth:
      // Android no permite pedir "solo rostro" o "solo huella".
      verificado = await _verificarBiometria();
    }
    if (isClosed) return;

    if (!verificado) {
      emit(state.copyWith(
        status: LoginStatus.listo,
        errorMessage: 'No se pudo verificar tu identidad. Tocá el botón para reintentar.',
      ));
      return;
    }

    final organizacionId = dataService.currentOrganizacionId;
    if (organizacionId == null) {
      emit(state.copyWith(
        status: LoginStatus.listo,
        errorMessage: 'No se pudo determinar tu organización. Volvé a iniciar sesión.',
      ));
      return;
    }
    _completarLogin(account, organizacionId);
  }

  void _completarLogin(GoogleSignInAccount account, String organizacionId) {
    _cuentaPendiente = null;
    authCubit.login(email: account.email, organizacionId: organizacionId);
    if (isClosed) return;
    emit(state.copyWith(status: LoginStatus.autenticado, clearMetodoPendiente: true));
  }

  /// Si el dispositivo no soporta biometría (sin hardware o sin nada
  /// enrolado), se omite el chequeo en vez de bloquear el acceso.
  Future<bool> _verificarBiometria() async {
    final available = await biometricAuthService.isAvailable();
    if (!available) {
      Logger.warning(
        'Método biométrico habilitado para la organización, pero el dispositivo no lo soporta; se omite el chequeo.',
      );
      return true;
    }
    return biometricAuthService.authenticate(
      reason: 'Confirmá tu identidad para completar el inicio de sesión',
    );
  }
}
