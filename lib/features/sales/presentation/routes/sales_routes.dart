import 'package:go_router/go_router.dart';
import '../../../../core/router/feature_route_definition.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../controllers/sales_controller.dart';
import '../pages/sale_detail_page.dart';
import '../pages/sales_page.dart';

/// Rutas modulares para la feature Sales.
class SalesRoutes implements FeatureRouteDefinition {
  final SalesController controller;
  final SheetsDataService dataService;

  const SalesRoutes({
    required this.controller,
    required this.dataService,
  });

  @override
  List<RouteBase> buildRoutes() {
    return [
      GoRoute(
        path: RoutePaths.ventas,
        name: RouteNames.ventas,
        builder: (context, state) => SalesPage(
          controller: controller,
          dataService: dataService,
        ),
        routes: [
          GoRoute(
            path: ':id',
            name: RouteNames.ventaDetalle,
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return SaleDetailPage(
                saleId: id,
                controller: controller,
                dataService: dataService,
              );
            },
          ),
        ],
      ),
    ];
  }
}
