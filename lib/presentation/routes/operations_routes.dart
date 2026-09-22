import 'package:go_router/go_router.dart';
import '../../core/router/feature_route_definition.dart';
import '../../core/router/route_names.dart';
import '../../core/router/route_paths.dart';
import '../../shared/google_sheets/sheets_data_service.dart';
import '../pages/clientes_page.dart';
import '../pages/factura_detalle_page.dart';
import '../pages/inventario_page.dart';
import '../pages/ventas_page.dart';

/// Rutas para las operaciones de Clientes, Inventario y Ventas.
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
      GoRoute(
        path: RoutePaths.ventas,
        name: RouteNames.ventas,
        builder: (context, state) {
          final clienteId = state.uri.queryParameters['cliente'];
          return VentasPage(dataService: dataService, clienteIdInicial: clienteId);
        },
        routes: [
          GoRoute(
            path: ':id',
            name: RouteNames.ventaDetalle,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return FacturaDetallePage(ventaId: id, dataService: dataService);
            },
          ),
        ],
      ),
    ];
  }
}
