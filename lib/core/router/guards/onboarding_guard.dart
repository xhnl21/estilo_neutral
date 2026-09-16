import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/application/auth_notifier.dart';
import '../route_paths.dart';

/// Guard de onboarding para verificar que el usuario complete la inducción inicial.
class OnboardingGuard {
  final AuthNotifier authNotifier;

  const OnboardingGuard({required this.authNotifier});

  /// Evalúa si el usuario debe ser redirigido a la pantalla de onboarding o continuar.
  String? redirect(BuildContext context, GoRouterState state) {
    // Si no está autenticado, la redirección es responsabilidad de AuthGuard
    if (!authNotifier.isAuthenticated) {
      return null;
    }

    final bool isOnboarded = authNotifier.isOnboarded;
    final String location = state.matchedLocation;
    final bool isGoingToOnboarding = location == RoutePaths.onboarding;

    // Si está autenticado pero no ha completado onboarding:
    if (!isOnboarded && !isGoingToOnboarding) {
      return RoutePaths.onboarding;
    }

    // Si ya completó onboarding y quiere volver a ver la pantalla de onboarding:
    if (isOnboarded && isGoingToOnboarding) {
      return RoutePaths.ventas;
    }

    return null;
  }
}
