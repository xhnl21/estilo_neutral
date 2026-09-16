import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../pages/reporting_page.dart';

/// Rutas modulares para la feature Reporting.
class ReportingRoutes implements FeatureRouteDefinition {
  final SheetsDataService dataService;

  const ReportingRoutes({required this.dataService});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.resumenDiario,
        name: RouteNames.resumenDiario,
        builder: (context, state) => ReportingPage(dataService: dataService),
      ),
    ];
  }
}
