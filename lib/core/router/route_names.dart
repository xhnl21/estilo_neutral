/// Nombres simbólicos para las rutas de go_router.
/// Facilita el uso de `context.goNamed(...)` desacoplado de las URIs.
abstract class RouteNames {
  // Rutas públicas / sesión
  static const String splash = 'splash';
  static const String login = 'login';
  static const String onboarding = 'onboarding';

  // Operaciones
  static const String clientes = 'clientes';
  static const String inventario = 'inventario';
  static const String ventas = 'ventas';
  static const String ventaDetalle = 'ventaDetalle';
  static const String comprasDivisas = 'comprasDivisas';

  // Cierre y Finanzas
  static const String resumenDiario = 'resumenDiario';

  // Calidad y Gobierno ISO
  static const String cuarentena = 'cuarentena';
  static const String auditLog = 'auditLog';
  static const String reporteMigracion = 'reporteMigracion';
  static const String checklistIso = 'checklistIso';
}
