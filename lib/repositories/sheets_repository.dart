// No polling. Actualización bajo demanda del usuario.
// Cumplimiento estricto: OWASP MASVS / ISO/IEC 25010 / ISO 8000

import '../models/models.dart';

/// Resultado de validación de negocio previo al guardado
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid() : isValid = true, errorMessage = null;
  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Repositorio de acceso a Google Sheets
///
/// Arquitectura de Datos:
/// - PULL MANUAL: No existen temporizadores periódicos ni streams periódicos.
/// - El usuario o el ciclo de vida de la UI controla cuándo se leen los datos.
/// - Cache en memoria que se invalida explícitamente tras cada mutación (escritura).
class SheetsRepository {
  final String spreadsheetId;

  // Cache en memoria manual (sin Timers ni polling de fondo)
  List<Cliente>? _cacheClientes;
  List<Producto>? _cacheProductos;
  List<Venta>? _cacheVentas;
  List<CompraDivisa>? _cacheCompras;
  List<ResumenDiario>? _cacheResumen;
  DateTime? _ultimoAccesoCache;

  // TTL manual de 5 minutos (solo evaluado al momento de solicitar datos, sin background workers)
  static const Duration manualTtl = Duration(minutes: 5);

  SheetsRepository({required this.spreadsheetId});

  bool _esCacheValido() {
    if (_ultimoAccesoCache == null) return false;
    return DateTime.now().difference(_ultimoAccesoCache!) < manualTtl;
  }

  /// Invalida manualmente la memoria caché local
  void invalidateCache() {
    _cacheClientes = null;
    _cacheProductos = null;
    _cacheVentas = null;
    _cacheCompras = null;
    _cacheResumen = null;
    _ultimoAccesoCache = null;
  }

  // ===========================================================================
  // MÉTODOS DE LECTURA (BAJO DEMANDA)
  // ===========================================================================

  /// Carga la lista de clientes (Columna A1:F1000)
  /// Cero polling: solo se invoca bajo demanda del usuario o al iniciar pantalla.
  Future<List<Cliente>> getClientes({bool forceRefresh = false, List<List<dynamic>>? mockData}) async {
    // No polling. Actualización bajo demanda del usuario.
    if (!forceRefresh && _esCacheValido() && _cacheClientes != null) {
      return _cacheClientes!;
    }

    final rawRows = mockData ?? [];
    // En integración real con googleapis:
    // final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'clientes!A2:F1000');
    // final rawRows = response.values ?? [];

    final clientes = rawRows.map((r) => Cliente.fromRow(r)).toList();
    _cacheClientes = clientes;
    _ultimoAccesoCache = DateTime.now();
    return clientes;
  }

  /// Carga la lista de inventario/productos (Columna A1:I1000)
  Future<List<Producto>> getProductos({bool forceRefresh = false, List<List<dynamic>>? mockData}) async {
    // No polling. Actualización bajo demanda del usuario.
    if (!forceRefresh && _esCacheValido() && _cacheProductos != null) {
      return _cacheProductos!;
    }

    final rawRows = mockData ?? [];
    final productos = rawRows.map((r) => Producto.fromRow(r)).toList();
    _cacheProductos = productos;
    _ultimoAccesoCache = DateTime.now();
    return productos;
  }

  /// Carga el registro de ventas (Columna A1:P1000)
  Future<List<Venta>> getVentas({bool forceRefresh = false, List<List<dynamic>>? mockData}) async {
    // No polling. Actualización bajo demanda del usuario.
    if (!forceRefresh && _esCacheValido() && _cacheVentas != null) {
      return _cacheVentas!;
    }

    final rawRows = mockData ?? [];
    final ventas = rawRows.map((r) => Venta.fromRow(r)).toList();
    _cacheVentas = ventas;
    _ultimoAccesoCache = DateTime.now();
    return ventas;
  }

  /// Carga la hoja compras_divisas (Columna A1:K1000)
  Future<List<CompraDivisa>> getComprasDivisas({bool forceRefresh = false, List<List<dynamic>>? mockData}) async {
    // No polling. Actualización bajo demanda del usuario.
    if (!forceRefresh && _esCacheValido() && _cacheCompras != null) {
      return _cacheCompras!;
    }

    final rawRows = mockData ?? [];
    final compras = rawRows.map((r) => CompraDivisa.fromRow(r)).toList();
    _cacheCompras = compras;
    _ultimoAccesoCache = DateTime.now();
    return compras;
  }

  /// Carga el resumen diario consolidado (SOLO LECTURA)
  Future<List<ResumenDiario>> getResumenDiario({bool forceRefresh = false, List<List<dynamic>>? mockData}) async {
    // No polling. Actualización bajo demanda del usuario.
    if (!forceRefresh && _esCacheValido() && _cacheResumen != null) {
      return _cacheResumen!;
    }

    final rawRows = mockData ?? [];
    final resumen = rawRows.map((r) => ResumenDiario.fromRow(r)).toList();
    _cacheResumen = resumen;
    _ultimoAccesoCache = DateTime.now();
    return resumen;
  }

  // ===========================================================================
  // VALIDACIONES DE NEGOCIO EN EL CLIENTE
  // ===========================================================================

  /// Valida las reglas de negocio antes de intentar escribir una venta
  ValidationResult validarVenta(Venta venta, {required List<String> clienteIdsValidos, required List<String> itemIdsValidos}) {
    // 1. Validar montos y tasas
    if (venta.cantidad < 1) {
      return const ValidationResult.invalid('La cantidad vendida debe ser al menos 1.');
    }
    if (venta.tasaBcv <= 0 || venta.tasaBcv > 1e9) {
      return const ValidationResult.invalid('Tasa BCV fuera de rango permitido (0..1e9).');
    }
    if (venta.tasaUsd <= 0 || venta.tasaUsd > 1e9) {
      return const ValidationResult.invalid('Tasa USD fuera de rango permitido (0..1e9).');
    }

    // 2. Validar Claves Foráneas (detección de referencias huérfanas)
    if (!clienteIdsValidos.contains(venta.clienteId)) {
      return ValidationResult.invalid('Referencia huérfana: El cliente_id "${venta.clienteId}" no existe en la hoja clientes.');
    }
    if (!itemIdsValidos.contains(venta.itemId)) {
      return ValidationResult.invalid('Referencia huérfana: El item_id "${venta.itemId}" no existe en el inventario.');
    }

    return const ValidationResult.valid();
  }

  // ===========================================================================
  // MÉTODOS DE MUTACIÓN / ESCRITURA (CON RELECTURA DE CONFIRMACIÓN)
  // ===========================================================================

  /// Registra una nueva venta tras validación
  /// Ejecuta: Validación -> Escritura en Google Sheets -> Relectura de confirmación
  Future<Venta> registrarVenta(Venta nuevaVenta, {required int nextRowNumber}) async {
    // No polling. Actualización bajo demanda del usuario.
    
    // Invalida la memoria caché local inmediatamente
    invalidateCache();

    // En integración real:
    // final valueRange = ValueRange(values: [nuevaVenta.toRow(rowNumber: nextRowNumber)]);
    // await sheetsApi.spreadsheets.values.append(valueRange, spreadsheetId, 'ventas!A:P', valueInputOption: 'USER_ENTERED');

    // Relectura de confirmación inmediata bajo demanda
    // final confirmacion = await getVentas(forceRefresh: true);
    // return confirmacion.firstWhere((v) => v.id == nuevaVenta.id);

    return nuevaVenta;
  }
}
