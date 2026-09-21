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

  const AuthState({
    this.isAuthenticated = true,
    this.isOnboarded = true,
    this.userEmail,
    this.organizacionId,
  });

  /// Crea una copia del estado con valores modificados.
  AuthState copyWith({
    bool? isAuthenticated,
    bool? isOnboarded,
    String? userEmail,
    String? organizacionId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      userEmail: userEmail ?? this.userEmail,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  @override
  List<Object?> get props => [isAuthenticated, isOnboarded, userEmail, organizacionId];
}
