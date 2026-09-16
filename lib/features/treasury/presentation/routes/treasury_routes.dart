import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../pages/treasury_page.dart';

/// Rutas modulares para la feature Treasury.
class TreasuryRoutes implements FeatureRouteDefinition {
  final SheetsDataService dataService;

  const TreasuryRoutes({required this.dataService});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.comprasDivisas,
        name: RouteNames.comprasDivisas,
        builder: (context, state) => TreasuryPage(dataService: dataService),
      ),
    ];
  }
}
