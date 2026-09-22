/// Constantes de paths para go_router.
/// Centraliza todos los identificadores de ruta para evitar strings mágicos.
abstract class RoutePaths {
  // Rutas públicas y de autenticación
  static const String splash = '/splash';
  static const String login = '/login';
  static const String onboarding = '/onboarding';

  // Operaciones
  static const String clientes = '/clientes';
  static const String inventario = '/inventario';
  static const String ventas = '/ventas';
  static const String ventaDetalle = '/ventas/:id';
  static const String comprasDivisas = '/compras-divisas';

  // Cierre y Finanzas
  static const String resumenDiario = '/resumen-diario';

  // Calidad y Gobierno ISO
  static const String cuarentena = '/cuarentena';
  static const String auditLog = '/audit-log';
  static const String reporteMigracion = '/reporte-migracion';
  static const String checklistIso = '/checklist-iso';
  static const String seguridad = '/seguridad';

  // Administración (multi-organización y configuración)
  static const String usuarios = '/usuarios';
  static const String organizaciones = '/organizaciones';
  static const String metodosPago = '/metodos-pago';

  /// Helper para construir path de detalle de venta con id
  static String buildSaleDetailPath(String id) => '/ventas/$id';
}
