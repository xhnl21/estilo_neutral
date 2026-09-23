import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../presentation/pages/pages.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';

/// Rutas modulares para la feature Audit & Calidad ISO.
class AuditRoutes implements FeatureRouteDefinition {
  final SheetsDataService dataService;

  const AuditRoutes({required this.dataService});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.cuarentena,
        name: RouteNames.cuarentena,
        builder: (context, state) => CuarentenaPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.auditLog,
        name: RouteNames.auditLog,
        builder: (context, state) => AuditLogPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.reporteMigracion,
        name: RouteNames.reporteMigracion,
        builder: (context, state) => ReporteMigracionPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.checklistIso,
        name: RouteNames.checklistIso,
        builder: (context, state) => ChecklistIsoPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.seguridad,
        name: RouteNames.seguridad,
        builder: (context, state) => SeguridadPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.usuarios,
        name: RouteNames.usuarios,
        builder: (context, state) => UsuariosPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.organizaciones,
        name: RouteNames.organizaciones,
        builder: (context, state) => OrganizacionesPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.metodosPago,
        name: RouteNames.metodosPago,
        builder: (context, state) => MetodosPagoPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.tasas,
        name: RouteNames.tasas,
        builder: (context, state) => TasasPage(dataService: dataService),
      ),
    ];
  }
}
