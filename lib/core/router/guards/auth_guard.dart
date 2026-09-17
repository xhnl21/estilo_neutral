import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/application/auth_notifier.dart';
import '../route_paths.dart';

/// Guard de autenticación para redirecciones de navegación.
/// Desacoplado de infraestructura: consulta el estado a través de [AuthNotifier].
class AuthGuard {
  final AuthNotifier authNotifier;

  const AuthGuard({required this.authNotifier});

  /// Evalúa si el usuario tiene acceso a la ruta solicitada.
  /// Retorna un path de redirección o `null` si la navegación está permitida.
  String? redirect(BuildContext context, GoRouterState state) {
    final bool isAuthenticated = authNotifier.isAuthenticated;
    final String location = state.matchedLocation;

    final bool isSplashing = location == RoutePaths.splash;
    final bool isLoggingIn = location == RoutePaths.login;
    final bool isOnboarding = location == RoutePaths.onboarding;

    // 1. Si no está autenticado y busca acceder a una ruta privada:
    if (!isAuthenticated) {
      if (isSplashing || isLoggingIn || isOnboarding) {
        return null; // Permitir acceso a splash, login u onboarding
      }
      // Redirigir a login preservando la ruta previa en query parameters
      final Uri uri = Uri(
        path: RoutePaths.login,
        queryParameters: location != RoutePaths.ventas ? {'from': location} : null,
      );
      return uri.toString();
    }

    // 2. Si ya está autenticado y trata de ingresar a login:
    if (isLoggingIn) {
      final String? from = state.uri.queryParameters['from'];
      return (from != null && from.isNotEmpty) ? from : RoutePaths.ventas;
    }

    return null;
  }
}
