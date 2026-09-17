import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/audit/presentation/routes/audit_routes.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/presentation/routes/auth_routes.dart';
import '../../features/reporting/presentation/routes/reporting_routes.dart';
import '../../features/sales/presentation/controllers/sales_controller.dart';
import '../../features/sales/presentation/routes/sales_routes.dart';
import '../../features/treasury/presentation/routes/treasury_routes.dart';
import '../../presentation/routes/operations_routes.dart';
import '../../presentation/shell/main_shell.dart';
import '../../shared/google_sheets/sheets_data_service.dart';
import 'guards/auth_guard.dart';
import 'guards/onboarding_guard.dart';
import 'pages/not_found_page.dart';
import 'route_paths.dart';


/// Configuración centralizada de enrutamiento con go_router para Estilo Neutral.
/// Implementa StatefulShellRoute.indexedStack para preservar el estado de las 9 vistas.
class AppRouter {
  final AuthNotifier authNotifier;
  final SalesController salesController;
  final SheetsDataService dataService;
  final String initialLocation;

  late final AuthGuard _authGuard;
  late final OnboardingGuard _onboardingGuard;
  late final GoRouter router;

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  AppRouter({
    required this.authNotifier,
    required this.salesController,
    required this.dataService,
    this.initialLocation = RoutePaths.splash,
  }) {
    _authGuard = AuthGuard(authNotifier: authNotifier);
    _onboardingGuard = OnboardingGuard(authNotifier: authNotifier);

    final authRoutes = AuthRoutes(authNotifier: authNotifier);
    final salesRoutes = SalesRoutes(controller: salesController, dataService: dataService);
    final treasuryRoutes = TreasuryRoutes(dataService: dataService);
    final reportingRoutes = ReportingRoutes(dataService: dataService);
    final operationsRoutes = OperationsRoutes(dataService: dataService);
    final auditRoutes = AuditRoutes(dataService: dataService);

    final opRoutesList = operationsRoutes.buildRoutes();
    final auditRoutesList = auditRoutes.buildRoutes();

    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      refreshListenable: authNotifier,
      redirect: (context, state) {
        final authRedirect = _authGuard.redirect(context, state);
        if (authRedirect != null) return authRedirect;

        final onboardingRedirect = _onboardingGuard.redirect(context, state);
        if (onboardingRedirect != null) return onboardingRedirect;

        return null;
      },
      errorBuilder: (context, state) => NotFoundPage(
        path: state.uri.toString(),
        error: state.error,
      ),
      routes: [
        // 1. Rutas independientes / de pantalla completa (Login y Onboarding)
        ...authRoutes.buildRoutes(),

        // 2. Shell persistente con las 9 vistas del sistema
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShell(
              salesController: salesController,
              dataService: dataService,
              navigationShell: navigationShell,
            );
          },
          branches: [
            // Rama 0: Clientes
            StatefulShellBranch(
              routes: [opRoutesList[0]],
            ),

            // Rama 1: Inventario (con soporte para query parameters ?q=)
            StatefulShellBranch(
              routes: [opRoutesList[1]],
            ),

            // Rama 2: Ventas y Detalle de Venta (:id)
            StatefulShellBranch(
              routes: salesRoutes.buildRoutes(),
            ),

            // Rama 3: Compras Divisas
            StatefulShellBranch(
              routes: treasuryRoutes.buildRoutes(),
            ),

            // Rama 4: Resumen Diario
            StatefulShellBranch(
              routes: reportingRoutes.buildRoutes(),
            ),

            // Rama 5: Cuarentena
            StatefulShellBranch(
              routes: [auditRoutesList[0]],
            ),

            // Rama 6: Audit Log
            StatefulShellBranch(
              routes: [auditRoutesList[1]],
            ),

            // Rama 7: Reporte Migración
            StatefulShellBranch(
              routes: [auditRoutesList[2]],
            ),

            // Rama 8: Checklist ISO
            StatefulShellBranch(
              routes: [auditRoutesList[3]],
            ),
          ],
        ),
      ],
    );

  }
}
