import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/application/auth_cubit.dart';
import '../route_paths.dart';

/// Guard de onboarding para verificar que el usuario complete la inducción inicial.
class OnboardingGuard {
  final AuthCubit authCubit;

  const OnboardingGuard({required this.authCubit});

  /// Evalúa si el usuario debe ser redirigido a la pantalla de onboarding o continuar.
  String? redirect(BuildContext context, GoRouterState state) {
    // Si no está autenticado, la redirección es responsabilidad de AuthGuard
    if (!authCubit.isAuthenticated) {
      return null;
    }

    final bool isOnboarded = authCubit.isOnboarded;
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
