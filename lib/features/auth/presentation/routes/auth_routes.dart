import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../application/auth_notifier.dart';
import '../pages/login_page.dart';
import '../pages/onboarding_page.dart';

/// Definición modular de rutas para la feature Auth.
class AuthRoutes implements FeatureRouteDefinition {
  final AuthNotifier authNotifier;

  const AuthRoutes({required this.authNotifier});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => LoginPage(authNotifier: authNotifier),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => OnboardingPage(authNotifier: authNotifier),
      ),
    ];
  }
}
