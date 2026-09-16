import 'package:go_router/go_router.dart';
import '../../core/router/feature_route_definition.dart';
import '../../core/router/route_names.dart';
import '../../core/router/route_paths.dart';
import '../../shared/google_sheets/sheets_data_service.dart';
import '../pages/clientes_page.dart';
import '../pages/inventario_page.dart';

/// Rutas para las operaciones de Clientes e Inventario.
class OperationsRoutes implements FeatureRouteDefinition {
  final SheetsDataService dataService;

  const OperationsRoutes({required this.dataService});

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.clientes,
        name: RouteNames.clientes,
        builder: (context, state) => ClientesPage(dataService: dataService),
      ),
      GoRoute(
        path: RoutePaths.inventario,
        name: RouteNames.inventario,
        builder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return InventarioPage(
            dataService: dataService,
            initialSearchQuery: query,
          );
        },
      ),
    ];
  }
}
