import 'package:local_auth/local_auth.dart';
import '../../core/utils/logger.dart';

/// Envuelve `local_auth` para pedir verificación biométrica (huella, Face ID)
/// como factor adicional durante el login, cuando está habilitado en la
/// hoja `seguridad` de la organización del usuario.
class BiometricAuthService {
  final LocalAuthentication _auth;

  BiometricAuthService({LocalAuthentication? localAuthentication})
      : _auth = localAuthentication ?? LocalAuthentication();

  /// Indica si el dispositivo soporta biometría y tiene al menos un método
  /// (huella, rostro, etc.) enrolado por el usuario en el sistema operativo.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al verificar disponibilidad de biometría',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Indica si el dispositivo tiene reconocimiento facial (Face ID / face
  /// unlock de clase fuerte) realmente disponible — no solo "algún método
  /// biométrico". En Android, muchos equipos (ej. sensores de huella sin
  /// cámara de profundidad) nunca reportan `BiometricType.face`, así que el
  /// botón de "Desbloqueo facial" no debería prometer Face ID en esos casos.
  Future<bool> hasFaceId() async {
    try {
      final tipos = await _auth.getAvailableBiometrics();
      return tipos.contains(BiometricType.face);
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error al consultar los tipos de biometría disponibles',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Cancelaciones esperables del usuario o del sistema — no son errores
  /// reales, solo "no completó la verificación esta vez".
  static const Set<LocalAuthExceptionCode> _codigosCancelacionBenigna = {
    LocalAuthExceptionCode.userCanceled,
    LocalAuthExceptionCode.systemCanceled,
  };

  /// Pide verificación biométrica al usuario. Devuelve `true` solo si se
  /// autenticó correctamente; `false` si canceló, falló o hubo un error.
  Future<bool> authenticate({
    String reason = 'Verificá tu identidad para continuar',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException catch (error, stackTrace) {
      // "authInProgress": el plugin de Android puede quedar con una sesión
      // de BiometricPrompt colgada (ej. si un intento previo se interrumpió
      // por un cambio de foco, giro de pantalla, etc.) — desde ese momento
      // TODA llamada a authenticate() falla de inmediato con este mismo
      // código, sin volver a mostrar el prompt, así que reintentar sin más
      // no sirve (el usuario queda atrapado tocando "reintentar" para
      // siempre). stopAuthentication() fuerza a cancelar esa sesión colgada
      // desde el lado nativo; una vez limpia, se reintenta una sola vez.
      if (error.code == LocalAuthExceptionCode.authInProgress) {
        Logger.warning('Sesión de biometría colgada (authInProgress); forzando cancelación y reintentando.');
        try {
          await _auth.stopAuthentication();
          // stopAuthentication() le pide a Android que cierre el
          // BiometricPrompt/Fragment anterior, pero esa destrucción no es
          // instantánea del lado nativo — reintentar en el mismo tick, sin
          // esperar, hace que el plugin todavía no tenga la Activity
          // "libre" para adjuntar un prompt nuevo (falla como "Client
          // activity was null", visto en los logs). Este pequeño respiro
          // le da tiempo a la Fragment anterior de desprenderse antes de
          // pedir una nueva.
          await Future.delayed(const Duration(milliseconds: 400));
          return await _auth.authenticate(
            localizedReason: reason,
            biometricOnly: true,
          );
        } catch (_) {
          // Si el reintento también falla, cae al mismo manejo de error de
          // abajo en vez de propagar una excepción distinta.
        }
      }

      // Si el usuario (o el sistema) canceló el diálogo, no es un error real
      // — se loguea como advertencia informativa, no como fallo.
      final esCancelacionBenigna = _codigosCancelacionBenigna.contains(error.code);
      Logger.log(
        message: esCancelacionBenigna
            ? 'Verificación biométrica cancelada (${error.code.name})'
            : 'Error durante la autenticación biométrica (${error.code.name})',
        type: esCancelacionBenigna ? LogType.warning : LogType.error,
        error: esCancelacionBenigna ? null : error,
        stackTrace: esCancelacionBenigna ? null : stackTrace,
      );
      return false;
    } catch (error, stackTrace) {
      Logger.log(
        message: 'Error durante la autenticación biométrica',
        type: LogType.error,
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
