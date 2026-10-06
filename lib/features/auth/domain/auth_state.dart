import 'package:equatable/equatable.dart';

/// Estado de sesión y autenticación del usuario.
class AuthState extends Equatable {
  /// Indica si el usuario está autenticado en la aplicación.
  final bool isAuthenticated;

  /// Indica si el usuario ha completado el onboarding inicial.
  final bool isOnboarded;

  /// Correo electrónico o identificador del usuario autenticado.
  final String? userEmail;

  /// Identificador de la organización resuelta para el usuario autenticado
  /// (a partir de la hoja "usuarios"), o null si aún no se ha resuelto.
  final String? organizacionId;

  /// Por qué se cerró la sesión sin que el usuario lo pidiera (p. ej. le
  /// quitaron el acceso); la pantalla de login lo muestra. `null` si no aplica.
  final String? motivoCierreSesion;

  const AuthState({
    this.isAuthenticated = true,
    this.isOnboarded = true,
    this.userEmail,
    this.organizacionId,
    this.motivoCierreSesion,
  });

  /// Crea una copia del estado con valores modificados.
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isOnboarded,
    String? userEmail,
    String? organizacionId,
    String? motivoCierreSesion,
    bool clearMotivoCierreSesion = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      userEmail: userEmail ?? this.userEmail,
      organizacionId: organizacionId ?? this.organizacionId,
      motivoCierreSesion: clearMotivoCierreSesion
          ? null
          : (motivoCierreSesion ?? this.motivoCierreSesion),
    );
  }

  @override
  List<Object?> get props =>
      [isAuthenticated, isOnboarded, userEmail, organizacionId, motivoCierreSesion];
}
