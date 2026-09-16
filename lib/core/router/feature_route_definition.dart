import 'package:go_router/go_router.dart';

/// Interfaz para exponer rutas de forma modular por cada Bounded Context (Feature).
abstract class FeatureRouteDefinition {
  /// Retorna la lista de rutas correspondientes a la feature.
  List<RouteBase> buildRoutes();
}
