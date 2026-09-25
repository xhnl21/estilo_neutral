import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/google_sheets/sheets_auth.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/auth_cubit.dart';
import '../../../../presentation/screens/splash/splash.dart';
import '../pages/login_page.dart';
import '../pages/onboarding_page.dart';

/// Definición modular de rutas para la feature Auth.
class AuthRoutes implements FeatureRouteDefinition {
  final AuthCubit authCubit;
  final SheetsAuth sheetsAuth;
  final SheetsDataService dataService;

  const AuthRoutes({required this.authCubit, required this.sheetsAuth, required this.dataService});

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
          authCubit: authCubit,
          sheetsAuth: sheetsAuth,
          dataService: dataService,
        ),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        name: RouteNames.onboarding,
        builder: (context, state) => OnboardingPage(authCubit: authCubit),
      ),
    ];
  }
}
