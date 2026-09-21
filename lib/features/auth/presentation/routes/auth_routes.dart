import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_notifier.dart';
import '../../../../presentation/screens/splash/splash.dart';
import '../pages/login_page.dart';
import '../pages/onboarding_page.dart';

/// Definición modular de rutas para la feature Auth.
class AuthRoutes implements FeatureRouteDefinition {
  final AuthNotifier authNotifier;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;

  const AuthRoutes({required this.authNotifier, required this.sheetsAuth, required this.dataService});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => LoginPage(
          authNotifier: authNotifier,
          sheetsAuth: sheetsAuth,
          dataService: dataService,
        ),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => OnboardingPage(authNotifier: authNotifier),
      ),
    ];
  }
}
