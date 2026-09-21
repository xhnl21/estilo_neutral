import 'package:flutter/foundation.dart';
import '../domain/auth_state.dart';

/// Notificador observable de la capa de aplicación para el estado de autenticación.
/// Implementa [ChangeNotifier] para alimentar directamente el `refreshListenable` de go_router.
class AuthNotifier extends ChangeNotifier {
  AuthState _state;

  /// Constructor con estado inicial configurable (por defecto autenticado para acceso a Sheets).
  AuthNotifier({AuthState? initialState})
      : _state = initialState ?? const AuthState();

  /// Estado actual inmutable.
  AuthState get state => _state;

  /// Indica si el usuario está autenticado.
  bool get isAuthenticated => _state.isAuthenticated;

  /// Indica si el usuario completó el onboarding.
  bool get isOnboarded => _state.isOnboarded;

  /// Email del usuario actual.
  String? get userEmail => _state.userEmail;

  /// Identificador de la organización resuelta para el usuario actual.
  String? get organizacionId => _state.organizacionId;

  /// Inicia sesión del usuario y notifica a los listeners.
  void login({String email = 'usuario@estiloneutral.com', String? organizacionId}) {
    _state = _state.copyWith(
      isAuthenticated: true,
      userEmail: email,
      organizacionId: organizacionId,
    );
    notifyListeners();
  }

  /// Cierra la sesión activa y notifica a los listeners.
  void logout() {
    _state = AuthState(
      isAuthenticated: false,
      isOnboarded: _state.isOnboarded,
      userEmail: null,
      organizacionId: null,
    );
    notifyListeners();
  }

  /// Marca el onboarding como completado y notifica a los listeners.
  void completeOnboarding() {
    _state = _state.copyWith(isOnboarded: true);
    notifyListeners();
  }

  /// Restablece el estado con valores explícitos (útil para pruebas unitarias).
  void setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }
}
