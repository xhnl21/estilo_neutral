import 'package:equatable/equatable.dart';

enum LoginStatus {
  /// Restaurando la sesión de Google en silencio al abrir la pantalla.
  restaurando,

  /// Esperando que el usuario toque el botón.
  listo,

  /// Abriendo el selector de Google, resolviendo el acceso o verificando el
  /// método de seguridad.
  procesando,

  /// Login completo: la vista navega.
  autenticado,
}

/// Estado inmutable de la pantalla de inicio de sesión.
class LoginState extends Equatable {
  final LoginStatus status;

  /// Método de seguridad pendiente de confirmar ('biometrico',
  /// 'desbloqueo_facial', 'dos_factores'), o `null` si no hay ninguno.
  final String? metodoPendiente;

  final String? errorMessage;

  const LoginState({
    this.status = LoginStatus.restaurando,
    this.metodoPendiente,
    this.errorMessage,
  });

  bool get isBusy =>
      status == LoginStatus.restaurando || status == LoginStatus.procesando;

  /// El botón se muestra en cuanto termina la restauración silenciosa.
  bool get showButton => status != LoginStatus.restaurando;

  LoginState copyWith({
    LoginStatus? status,
    String? metodoPendiente,
    bool clearMetodoPendiente = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      metodoPendiente:
          clearMetodoPendiente ? null : (metodoPendiente ?? this.metodoPendiente),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, metodoPendiente, errorMessage];
}
