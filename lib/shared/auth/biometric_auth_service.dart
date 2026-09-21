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
