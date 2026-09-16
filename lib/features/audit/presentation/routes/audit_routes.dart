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
    ];
  }
}
