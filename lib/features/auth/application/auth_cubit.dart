import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/auth_state.dart';

/// Cubit de la capa de aplicación para el estado de autenticación.
/// Su `stream` alimenta el `refreshListenable` de go_router a través de
/// `GoRouterRefreshStream` (ver `AppRouter`) — go_router espera un
/// `Listenable`, no un `Cubit`, por eso el puente vía stream en vez de una
/// dependencia directa.
class AuthCubit extends Cubit<AuthState> {
  /// Constructor con estado inicial configurable (por defecto autenticado para acceso a Sheets).
  AuthCubit({AuthState? initialState}) : super(initialState ?? const AuthState());

  /// Indica si el usuario está autenticado.
  bool get isAuthenticated => state.isAuthenticated;

  /// Indica si el usuario completó el onboarding.
  bool get isOnboarded => state.isOnboarded;

  /// Email del usuario actual.
  String? get userEmail => state.userEmail;

  /// Identificador de la organización resuelta para el usuario actual.
  String? get organizacionId => state.organizacionId;

  /// Inicia sesión del usuario.
  void login({String email = 'usuario@estiloneutral.com', String? organizacionId}) {
    emit(state.copyWith(
      isAuthenticated: true,
      userEmail: email,
      organizacionId: organizacionId,
    ));
  }

  /// Cierra la sesión activa.
  void logout() {
    emit(AuthState(
      isAuthenticated: false,
      isOnboarded: state.isOnboarded,
      userEmail: null,
      organizacionId: null,
    ));
  }

  /// Marca el onboarding como completado.
  void completeOnboarding() {
    emit(state.copyWith(isOnboarded: true));
  }

  /// Restablece el estado con valores explícitos (útil para pruebas unitarias).
  void setState(AuthState newState) {
    emit(newState);
  }
}
