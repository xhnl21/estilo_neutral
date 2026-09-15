import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/models.dart';
import '../storage/secure_token_storage.dart';
import 'sheets_config.dart';

/// Servicio centralizado de datos y sincronización para las 9 hojas de Google Sheets.
/// Arquitectura: Cero Polling, actualización bajo demanda, estado reactivo con CRUD completo
/// y trazabilidad de auditoría ISO 27001 / ISO 8000.
class SheetsDataService extends ChangeNotifier {
  final String spreadsheetId;
  String? _appsScriptUrl;
  String? get appsScriptUrl => _appsScriptUrl;
  final http.Client _httpClient;

  SheetsDataService({
    String? spreadsheetId,
    String? appsScriptUrl,
    http.Client? httpClient,
  })  : spreadsheetId = SheetsConfig.extractSpreadsheetId(spreadsheetId ?? SheetsConfig.defaultSpreadsheetId),
        _appsScriptUrl = appsScriptUrl ?? SheetsConfig.defaultAppsScriptUrl,
        _httpClient = httpClient ?? http.Client();

  Future<void> setAppsScriptUrl(String url) async {
    _appsScriptUrl = url.trim();
    try {
      await SecureTokenStorage().saveAppsScriptUrl(_appsScriptUrl ?? '');
    } catch (_) {}
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  // Colecciones en memoria para las 9 hojas
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  List<Venta> _ventas = [];
  List<CompraDivisa> _comprasDivisas = [];
  List<ResumenDiario> _resumenesDiarios = [];
  List<RegistroCuarentena> _cuarentenas = [];
  List<AuditLog> _auditLogs = [];
  List<ReporteMigracion> _reportesMigracion = [];
  List<ChecklistISO> _checklistIsos = [];

  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Producto> get productos => List.unmodifiable(_productos);
  List<Venta> get ventas => List.unmodifiable(_ventas);
  List<CompraDivisa> get comprasDivisas => List.unmodifiable(_comprasDivisas);
  List<ResumenDiario> get resumenesDiarios => List.unmodifiable(_resumenesDiarios);
  List<RegistroCuarentena> get cuarentenas => List.unmodifiable(_cuarentenas);
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);
  List<ReporteMigracion> get reportesMigracion => List.unmodifiable(_reportesMigracion);
  List<ChecklistISO> get checklistIsos => List.unmodifiable(_checklistIsos);

  /// Carga inicial de datos
  Future<void> initialize() async {
    try {
      final savedUrl = await SecureTokenStorage().getAppsScriptUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _appsScriptUrl = savedUrl;
      }
    } catch (_) {}
    _seedFallbackData();
    await fetchAllSheets();
  }

  /// Carga bajo demanda de las 9 hojas desde Google Sheets mediante el endpoint GViz
  Future<void> fetchAllSheets({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    int successCount = 0;
    final errors = <String>[];

    Future<void> safeFetch(String name, void Function(List<List<String>>) parser) async {
      try {
        await _fetchSheet(name, parser);
        successCount++;
      } catch (e) {
        errors.add('$name: $e');
        debugPrint('Error fetching sheet $name: $e');
      }
    }

    try {
      await Future.wait([
        safeFetch('clientes', _parseClientes),
        safeFetch('inventario', _parseProductos),
        safeFetch('ventas', _parseVentas),
        safeFetch('compras_divisas', _parseCompras),
        safeFetch('resumen_diario', _parseResumenes),
        safeFetch('cuarentena', _parseCuarentenas),
        safeFetch('audit_log', _parseAuditLogs),
        safeFetch('reporte_migracion', _parseReportes),
        safeFetch('checklist_iso', _parseChecklists),
      ]);

      if (successCount > 0) {
        _lastSync = DateTime.now();
        _errorMessage = null;
      } else {
        _errorMessage = 'Sin conexión con Google Sheets: operando con caché local.';
      }
    } catch (e) {
      _errorMessage = 'Sin conexión con Google Sheets: operando con caché local.';
      debugPrint('SheetsDataService fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSheet(String sheetName, void Function(List<List<String>>) parser) async {
    final cleanId = SheetsConfig.extractSpreadsheetId(spreadsheetId);
    final url = Uri.parse(
      'https://docs.google.com/spreadsheets/d/$cleanId/gviz/tq?tqx=out:csv&sheet=$sheetName',
    );
    final response = await _httpClient.get(url, headers: {
      'User-Agent': 'Flutter-EstiloNeutral/1.0',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final rows = parseCsv(response.body);
      if (rows.length > 1) {
        parser(rows.sublist(1));
      }
    } else if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  // ===========================================================================
  // PARSERS
  // ===========================================================================

  void _parseClientes(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows.map((r) => Cliente.fromRow(r)).toList();
    final localPending = _clientes.where((local) => !cloud.any((c) => c.id == local.id)).toList();
    _clientes = [...cloud, ...localPending];
  }

  void _parseProductos(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows.map((r) => Producto.fromRow(r)).toList();
    final localPending = _productos.where((local) => !cloud.any((p) => p.id == local.id)).toList();
    _productos = [...cloud, ...localPending];
  }

  void _parseVentas(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows.map((r) => Venta.fromRow(r)).toList();
    final localPending = _ventas.where((local) => !cloud.any((v) => v.id == local.id)).toList();
    _ventas = [...cloud, ...localPending];
  }

  void _parseCompras(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows
        .where((r) => r.isNotEmpty && r.first.isNotEmpty)
        .map((r) => CompraDivisa.fromRow(r))
        .toList();
    final localPending = _comprasDivisas.where((local) => !cloud.any((c) => c.id == local.id)).toList();
    _comprasDivisas = [...cloud, ...localPending];
  }

  void _parseResumenes(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _resumenesDiarios = rows.map((r) => ResumenDiario.fromRow(r)).toList();
  }

  void _parseCuarentenas(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _cuarentenas = rows.map((r) => RegistroCuarentena.fromRow(r)).toList();
  }

  void _parseAuditLogs(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _auditLogs = rows.map((r) => AuditLog.fromRow(r)).toList();
  }

  void _parseReportes(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _reportesMigracion = rows
        .where((r) => r.isNotEmpty && r.first.isNotEmpty && !r.first.startsWith('REPORTE') && !r.first.startsWith('Estándares'))
        .map((r) => ReporteMigracion.fromRow(r))
        .toList();
  }

  void _parseChecklists(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _checklistIsos = rows.map((r) => ChecklistISO.fromRow(r)).toList();
  }

  // ===========================================================================
  // AUDIT LOG HELPER (ISO 27001 §8.13 / ISO 8000)
  // ===========================================================================

  void _logAudit({
    required String hoja,
    required String celda,
    required String valorAnterior,
    required String valorNuevo,
    required String accion,
    required String norma,
    required String observaciones,
  }) {
    final log = AuditLog(
      timestampIso8601: DateTime.now(),
      usuario: 'Operador App (CRUD Móvil)',
      hoja: hoja,
      celda: celda,
      valorAnterior: valorAnterior,
      valorNuevo: valorNuevo,
      accion: accion,
      normaAplicada: norma,
      observaciones: observaciones,
    );
    _auditLogs.insert(0, log);
  }

  /// Sincroniza de forma asíncrona la acción con la Web App de Google Apps Script (Opción A)
  Future<bool> _postToAppsScript(Map<String, dynamic> payload) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      return false;
    }
    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('AppsScript sync error: $e');
      return false;
    }
  }

  /// Sube una imagen directamente a la carpeta de Google Drive configurada vía Web App
  Future<String?> uploadImageToDrive({
    required List<int> bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      return null;
    }
    try {
      final base64Data = base64Encode(bytes);
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'upload_image',
          'fileName': fileName,
          'mimeType': mimeType,
          'base64Data': base64Data,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['fileUrl'] != null) {
          return data['fileUrl'] as String;
        }
      }
    } catch (e) {
      debugPrint('Error uploading image to Google Drive: $e');
    }
    return null;
  }

  // ===========================================================================
  // CRUD 1: CLIENTES (hoja clientes)
  // ===========================================================================

  String get nextClienteId {
    final maxId = _clientes.fold<int>(0, (prev, c) {
      final numStr = c.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'c${(maxId + 1).toString().padLeft(8, '0')}';
  }

  Future<bool> addCliente(Cliente cliente) async {
    _clientes.add(cliente);
    _logAudit(
      hoja: 'clientes',
      celda: 'A${_clientes.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${cliente.id} (${cliente.nombre})',
      accion: 'creacion_cliente',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Alta de cliente con teléfono ${cliente.telefono}',
    );
    notifyListeners();
    return await _postToAppsScript({
      'action': 'create',
      'sheet': 'clientes',
      'data': cliente.toMap(),
    });
  }

  void updateCliente(Cliente cliente) {
    final index = _clientes.indexWhere((c) => c.id == cliente.id);
    if (index != -1) {
      final old = _clientes[index];
      _clientes[index] = cliente;
      _logAudit(
        hoja: 'clientes',
        celda: 'A${index + 2}',
        valorAnterior: '${old.nombre} | ${old.telefono} | ${old.email}',
        valorNuevo: '${cliente.nombre} | ${cliente.telefono} | ${cliente.email}',
        accion: 'actualizacion_cliente',
        norma: 'ISO 8000 §4.2',
        observaciones: 'Modificación de datos de cliente ${cliente.id}',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'clientes',
        'id': cliente.id,
        'data': cliente.toMap(),
      });
      notifyListeners();
    }
  }

  void deleteCliente(String id) {
    final index = _clientes.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = _clientes.removeAt(index);
      _logAudit(
        hoja: 'clientes',
        celda: 'A${index + 2}',
        valorAnterior: '${old.id}: ${old.nombre}',
        valorNuevo: 'ELIMINADO',
        accion: 'eliminacion_cliente',
        norma: 'GDPR Art. 17 / ISO 27001',
        observaciones: 'Baja del cliente $id',
      );
      _postToAppsScript({
        'action': 'delete',
        'sheet': 'clientes',
        'id': id,
      });
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 2: INVENTARIO (hoja inventario)
  // ===========================================================================

  String get nextProductoId {
    final maxId = _productos.fold<int>(0, (prev, p) {
      final numStr = p.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'p${(maxId + 1).toString().padLeft(8, '0')}';
  }

  void addProducto(Producto producto) {
    _productos.add(producto);
    _logAudit(
      hoja: 'inventario',
      celda: 'A${_productos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${producto.id} (${producto.nombre})',
      accion: 'creacion_producto',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Nuevo producto en inventario. Stock inicial: ${producto.cantidad}',
    );
    _postToAppsScript({
      'action': 'create',
      'sheet': 'inventario',
      'data': producto.toMap(),
    });
    notifyListeners();
  }

  void updateProducto(Producto producto) {
    final index = _productos.indexWhere((p) => p.id == producto.id);
    if (index != -1) {
      final old = _productos[index];
      _productos[index] = producto;
      _logAudit(
        hoja: 'inventario',
        celda: 'A${index + 2}',
        valorAnterior: '${old.nombre}, ${old.talla}, USD ${old.precioUsd}',
        valorNuevo: '${producto.nombre}, ${producto.talla}, USD ${producto.precioUsd}',
        accion: 'actualizacion_producto',
        norma: 'ISO 8000 §4.2',
        observaciones: 'Actualización de producto ${producto.id}',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'inventario',
        'id': producto.id,
        'data': producto.toMap(),
      });
      notifyListeners();
    }
  }

  void adjustStock(String id, int delta) {
    final index = _productos.indexWhere((p) => p.id == id);
    if (index != -1) {
      final old = _productos[index];
      final newQty = (old.cantidad + delta).clamp(0, 999999);
      _productos[index] = Producto(
        id: old.id,
        cantidad: newQty,
        nombre: old.nombre,
        marca: old.marca,
        modelo: old.modelo,
        talla: old.talla,
        precioUsd: old.precioUsd,
        fotoUrl: old.fotoUrl,
      );
      _logAudit(
        hoja: 'inventario',
        celda: 'B${index + 2}',
        valorAnterior: 'Stock: ${old.cantidad}',
        valorNuevo: 'Stock: $newQty',
        accion: 'ajuste_stock',
        norma: 'ISO 8000 §4.2',
        observaciones: 'Ajuste manual de stock ($delta)',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'inventario',
        'id': id,
        'data': {'cantidad': newQty},
      });
      notifyListeners();
    }
  }

  void deleteProducto(String id) {
    final index = _productos.indexWhere((p) => p.id == id);
    if (index != -1) {
      final old = _productos.removeAt(index);
      _logAudit(
        hoja: 'inventario',
        celda: 'A${index + 2}',
        valorAnterior: '${old.id}: ${old.nombre}',
        valorNuevo: 'ELIMINADO',
        accion: 'eliminacion_producto',
        norma: 'ISO 8000',
        observaciones: 'Desincorporación de producto $id',
      );
      _postToAppsScript({
        'action': 'delete',
        'sheet': 'inventario',
        'id': id,
      });
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 3: VENTAS (hoja ventas)
  // ===========================================================================

  String get nextVentaId {
    final maxId = _ventas.fold<int>(0, (prev, v) {
      final numStr = v.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'v${(maxId + 1).toString().padLeft(8, '0')}';
  }

  void addVenta(Venta venta) {
    _ventas.insert(0, venta);

    // Decrementar existencias en inventario
    adjustStock(venta.itemId, -venta.cantidad);

    // Ajustar saldo de deuda del cliente si queda saldo pendiente
    if (venta.deudaUsd > 0) {
      final cIdx = _clientes.indexWhere((c) => c.id == venta.clienteId);
      if (cIdx != -1) {
        final c = _clientes[cIdx];
        _clientes[cIdx] = Cliente(
          id: c.id,
          nombre: c.nombre,
          telefono: c.telefono,
          email: c.email,
          saldoDeudaUsd: c.saldoDeudaUsd + venta.deudaUsd,
          fechaRegistro: c.fechaRegistro,
        );
      }
    }

    _logAudit(
      hoja: 'ventas',
      celda: 'A${_ventas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${venta.id} por USD ${venta.totalPagarUsd.toStringAsFixed(2)}',
      accion: 'creacion_venta',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Venta registrada a cliente ${venta.clienteId}, ítem ${venta.itemId}',
    );
    _postToAppsScript({
      'action': 'create',
      'sheet': 'ventas',
      'data': venta.toMap(),
    });
    notifyListeners();
  }

  void updateVenta(Venta venta) {
    final index = _ventas.indexWhere((v) => v.id == venta.id);
    if (index != -1) {
      _ventas[index] = venta;
      _logAudit(
        hoja: 'ventas',
        celda: 'A${index + 2}',
        valorAnterior: 'Venta ${venta.id}',
        valorNuevo: 'Estado: ${venta.estado.name}',
        accion: 'actualizacion_venta',
        norma: 'ISO 8000 §5.3',
        observaciones: 'Actualización en venta ${venta.id}',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'ventas',
        'id': venta.id,
        'data': venta.toMap(),
      });
      notifyListeners();
    }
  }

  void registrarAbono(String ventaId, double montoAbono) {
    final index = _ventas.indexWhere((v) => v.id == ventaId);
    if (index != -1) {
      final old = _ventas[index];
      final nuevoAbono = old.abonoUsd + montoAbono;
      final nuevaDeuda = (old.totalPagarUsd - nuevoAbono).clamp(0.0, double.infinity);
      final nuevoEstado = nuevaDeuda == 0 ? EstadoVenta.pagada : EstadoVenta.pendiente;

      _ventas[index] = Venta(
        id: old.id,
        fecha: old.fecha,
        clienteId: old.clienteId,
        itemId: old.itemId,
        cantidad: old.cantidad,
        tasaBcv: old.tasaBcv,
        tasaUsd: old.tasaUsd,
        tipoPago: old.tipoPago,
        comisionPagoMovilBs: old.comisionPagoMovilBs,
        montoBs: old.montoBs,
        montoUsd: old.montoUsd,
        abonoUsd: nuevoAbono,
        deudaUsd: nuevaDeuda,
        totalPagarUsd: old.totalPagarUsd,
        validacion: 'OK',
        estado: nuevoEstado,
      );

      // Reducir saldo de deuda del cliente
      final cIdx = _clientes.indexWhere((c) => c.id == old.clienteId);
      if (cIdx != -1) {
        final c = _clientes[cIdx];
        _clientes[cIdx] = Cliente(
          id: c.id,
          nombre: c.nombre,
          telefono: c.telefono,
          email: c.email,
          saldoDeudaUsd: (c.saldoDeudaUsd - montoAbono).clamp(0.0, double.infinity),
          fechaRegistro: c.fechaRegistro,
        );
      }

      _logAudit(
        hoja: 'ventas',
        celda: 'L${index + 2}',
        valorAnterior: 'Deuda: ${old.deudaUsd}',
        valorNuevo: 'Abono +$montoAbono -> Deuda: $nuevaDeuda',
        accion: 'registro_abono',
        norma: 'ISO 8000 §5.3',
        observaciones: 'Abono a venta $ventaId. Estado: ${nuevoEstado.name}',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'ventas',
        'id': ventaId,
        'data': _ventas[index].toMap(),
      });
      notifyListeners();
    }
  }

  void deleteVenta(String id) {
    final index = _ventas.indexWhere((v) => v.id == id);
    if (index != -1) {
      final old = _ventas.removeAt(index);
      _logAudit(
        hoja: 'ventas',
        celda: 'A${index + 2}',
        valorAnterior: 'Venta ${old.id}',
        valorNuevo: 'ANULADA/ELIMINADA',
        accion: 'anulacion_venta',
        norma: 'ISO 8000',
        observaciones: 'Venta $id anulada',
      );
      _postToAppsScript({
        'action': 'delete',
        'sheet': 'ventas',
        'id': id,
      });
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 4: COMPRAS DIVISAS (hoja compras_divisas)
  // ===========================================================================

  String get nextCompraDivisaId {
    final maxId = _comprasDivisas.fold<int>(0, (prev, c) {
      final numStr = c.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'd${(maxId + 1).toString().padLeft(8, '0')}';
  }

  void addCompraDivisa(CompraDivisa compra) {
    _comprasDivisas.insert(0, compra);
    _logAudit(
      hoja: 'compras_divisas',
      celda: 'A${_comprasDivisas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${compra.id}: USD ${compra.capitalUsd}',
      accion: 'registro_compra_divisa',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Compra cambiaria en ${compra.plataforma} por ${compra.vendedor}',
    );
    _postToAppsScript({
      'action': 'create',
      'sheet': 'compras_divisas',
      'data': compra.toMap(),
    });
    notifyListeners();
  }

  void updateCompraDivisa(CompraDivisa compra) {
    final index = _comprasDivisas.indexWhere((c) => c.id == compra.id);
    if (index != -1) {
      _comprasDivisas[index] = compra;
      _logAudit(
        hoja: 'compras_divisas',
        celda: 'A${index + 2}',
        valorAnterior: 'Orden ${compra.id}',
        valorNuevo: 'Capital: ${compra.capitalUsd} | Com: ${compra.comisionBinanceUsd}',
        accion: 'actualizacion_compra_divisa',
        norma: 'ISO 8000 §4.2',
        observaciones: 'Modificación en orden cambiaria ${compra.id}',
      );
      _postToAppsScript({
        'action': 'update',
        'sheet': 'compras_divisas',
        'id': compra.id,
        'data': compra.toMap(),
      });
      notifyListeners();
    }
  }

  void deleteCompraDivisa(String id) {
    final index = _comprasDivisas.indexWhere((c) => c.id == id);
    if (index != -1) {
      final old = _comprasDivisas.removeAt(index);
      _logAudit(
        hoja: 'compras_divisas',
        celda: 'A${index + 2}',
        valorAnterior: 'Orden ${old.id}',
        valorNuevo: 'ELIMINADA',
        accion: 'eliminacion_compra_divisa',
        norma: 'ISO 8000',
        observaciones: 'Orden cambiaria $id eliminada',
      );
      _postToAppsScript({
        'action': 'delete',
        'sheet': 'compras_divisas',
        'id': id,
      });
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 5: RESUMEN DIARIO (hoja resumen_diario)
  // ===========================================================================

  void addResumenDiario(ResumenDiario resumen) {
    final existingIdx = _resumenesDiarios.indexWhere((r) => r.fecha == resumen.fecha);
    if (existingIdx != -1) {
      _resumenesDiarios[existingIdx] = resumen;
    } else {
      _resumenesDiarios.insert(0, resumen);
    }
    _logAudit(
      hoja: 'resumen_diario',
      celda: 'A${_resumenesDiarios.length + 1}',
      valorAnterior: 'null',
      valorNuevo: 'Cierre ${resumen.fecha}: USD ${resumen.totalUsd}',
      accion: 'cierre_diario',
      norma: 'COBIT 2019 / ISO 27001',
      observaciones: 'Registro de balance diario para ${resumen.fecha}',
    );
    notifyListeners();
  }

  void updateResumenDiario(ResumenDiario resumen) {
    final index = _resumenesDiarios.indexWhere((r) => r.fecha == resumen.fecha);
    if (index != -1) {
      _resumenesDiarios[index] = resumen;
      _logAudit(
        hoja: 'resumen_diario',
        celda: 'A${index + 2}',
        valorAnterior: 'Balance ${resumen.fecha}',
        valorNuevo: 'Actualizado: USD ${resumen.totalUsd}, Bs ${resumen.totalBs}',
        accion: 'actualizacion_resumen_diario',
        norma: 'COBIT 2019',
        observaciones: 'Ajuste manual al cierre ${resumen.fecha}',
      );
      notifyListeners();
    }
  }

  void deleteResumenDiario(DateTime fecha) {
    final index = _resumenesDiarios.indexWhere((r) => r.fecha == fecha);
    if (index != -1) {
      _resumenesDiarios.removeAt(index);
      _logAudit(
        hoja: 'resumen_diario',
        celda: 'A${index + 2}',
        valorAnterior: 'Balance $fecha',
        valorNuevo: 'ELIMINADO',
        accion: 'eliminacion_resumen_diario',
        norma: 'COBIT 2019',
        observaciones: 'Eliminado cierre de fecha $fecha',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 6: CUARENTENA (hoja cuarentena)
  // ===========================================================================

  void addCuarentena(RegistroCuarentena item) {
    _cuarentenas.insert(0, item);
    _logAudit(
      hoja: 'cuarentena',
      celda: 'A${_cuarentenas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${item.idRegistroOriginal} (${item.motivoCuarentena})',
      accion: 'ingreso_cuarentena',
      norma: 'COBIT 2019 DSS05',
      observaciones: 'Anomalía aislada desde hoja ${item.hojaOrigen}',
    );
    notifyListeners();
  }

  void updateCuarentena(RegistroCuarentena item) {
    final index = _cuarentenas.indexWhere((c) => c.idRegistroOriginal == item.idRegistroOriginal);
    if (index != -1) {
      _cuarentenas[index] = item;
      _logAudit(
        hoja: 'cuarentena',
        celda: 'F${index + 2}',
        valorAnterior: 'Estado previo',
        valorNuevo: '${item.estado}: ${item.resolucion}',
        accion: 'resolucion_cuarentena',
        norma: 'COBIT 2019 DSS05',
        observaciones: 'Actualizada resolución para registro ${item.idRegistroOriginal}',
      );
      notifyListeners();
    }
  }

  void deleteCuarentena(String idOriginal) {
    final index = _cuarentenas.indexWhere((c) => c.idRegistroOriginal == idOriginal);
    if (index != -1) {
      _cuarentenas.removeAt(index);
      _logAudit(
        hoja: 'cuarentena',
        celda: 'A${index + 2}',
        valorAnterior: 'Registro $idOriginal',
        valorNuevo: 'PURGADO',
        accion: 'descarte_cuarentena',
        norma: 'COBIT 2019 DSS05',
        observaciones: 'Registro purgado de cuarentena',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 7: AUDIT LOG (hoja audit_log)
  // ===========================================================================

  void addAuditLogManual(AuditLog log) {
    _auditLogs.insert(0, log);
    notifyListeners();
  }

  void updateAuditLog(int index, String nuevasObservaciones) {
    if (index >= 0 && index < _auditLogs.length) {
      final old = _auditLogs[index];
      _auditLogs[index] = AuditLog(
        timestampIso8601: old.timestampIso8601,
        usuario: old.usuario,
        hoja: old.hoja,
        celda: old.celda,
        valorAnterior: old.valorAnterior,
        valorNuevo: old.valorNuevo,
        accion: old.accion,
        normaAplicada: old.normaAplicada,
        observaciones: nuevasObservaciones,
      );
      notifyListeners();
    }
  }

  void deleteAuditLog(int index) {
    if (index >= 0 && index < _auditLogs.length) {
      _auditLogs.removeAt(index);
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 8: REPORTE MIGRACIÓN (hoja reporte_migracion)
  // ===========================================================================

  void addReporteMigracion(ReporteMigracion rep) {
    _reportesMigracion.add(rep);
    _logAudit(
      hoja: 'reporte_migracion',
      celda: 'A${_reportesMigracion.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${rep.metrica}: ${rep.valorEstado}',
      accion: 'alta_control_migracion',
      norma: rep.normaAplicada,
      observaciones: rep.observaciones,
    );
    notifyListeners();
  }

  void updateReporteMigracion(int index, ReporteMigracion rep) {
    if (index >= 0 && index < _reportesMigracion.length) {
      _reportesMigracion[index] = rep;
      _logAudit(
        hoja: 'reporte_migracion',
        celda: 'B${index + 2}',
        valorAnterior: 'Modificado',
        valorNuevo: rep.valorEstado,
        accion: 'actualizacion_control_migracion',
        norma: rep.normaAplicada,
        observaciones: 'Ajuste en ${rep.metrica}',
      );
      notifyListeners();
    }
  }

  void deleteReporteMigracion(int index) {
    if (index >= 0 && index < _reportesMigracion.length) {
      final old = _reportesMigracion.removeAt(index);
      _logAudit(
        hoja: 'reporte_migracion',
        celda: 'A${index + 2}',
        valorAnterior: old.metrica,
        valorNuevo: 'ELIMINADO',
        accion: 'baja_control_migracion',
        norma: old.normaAplicada,
        observaciones: 'Control retirado del cuadro de mando',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // CRUD 9: CHECKLIST ISO (hoja checklist_iso)
  // ===========================================================================

  void addChecklistIso(ChecklistISO check) {
    _checklistIsos.add(check);
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'A${_checklistIsos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${check.control} (${check.norma})',
      accion: 'alta_requisito_iso',
      norma: check.norma,
      observaciones: check.evidencia,
    );
    notifyListeners();
  }

  void toggleChecklistEstado(int nro) {
    final index = _checklistIsos.indexWhere((c) => c.nro == nro);
    if (index != -1) {
      final old = _checklistIsos[index];
      final nuevoEstado = old.estado == '☑' ? '☐' : '☑';
      _checklistIsos[index] = ChecklistISO(
        nro: old.nro,
        control: old.control,
        norma: old.norma,
        estado: nuevoEstado,
        evidencia: old.evidencia,
        timestamp: DateTime.now(),
      );
      _logAudit(
        hoja: 'checklist_iso',
        celda: 'D${index + 2}',
        valorAnterior: old.estado,
        valorNuevo: nuevoEstado,
        accion: 'cambio_estado_conformidad',
        norma: old.norma,
        observaciones: 'Control #${old.nro} marcado como $nuevoEstado',
      );
      _postToAppsScript({
        'action': 'toggle_checklist',
        'sheet': 'checklist_iso',
        'nro': nro,
        'estado': nuevoEstado,
      });
      notifyListeners();
    }
  }

  void updateChecklistIso(ChecklistISO check) {
    final index = _checklistIsos.indexWhere((c) => c.nro == check.nro);
    if (index != -1) {
      _checklistIsos[index] = check;
      _logAudit(
        hoja: 'checklist_iso',
        celda: 'B${index + 2}',
        valorAnterior: 'Control #${check.nro}',
        valorNuevo: '${check.control} | ${check.estado}',
        accion: 'actualizacion_checklist',
        norma: check.norma,
        observaciones: check.evidencia,
      );
      notifyListeners();
    }
  }

  void deleteChecklistIso(int nro) {
    final index = _checklistIsos.indexWhere((c) => c.nro == nro);
    if (index != -1) {
      final old = _checklistIsos.removeAt(index);
      _logAudit(
        hoja: 'checklist_iso',
        celda: 'A${index + 2}',
        valorAnterior: 'Control #${old.nro}: ${old.control}',
        valorNuevo: 'ELIMINADO',
        accion: 'eliminacion_checklist',
        norma: old.norma,
        observaciones: 'Requisito retirado del checklist',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // SEED DE FALLBACK BASADO EN ESTILO NEUTRAL.XLSX
  // ===========================================================================

  void _seedFallbackData() {
    _clientes = [
      Cliente(
        id: 'c00000001',
        nombre: 'Neida',
        telefono: '+584120000001',
        email: 'neida.cliente@ejemplo.com',
        saldoDeudaUsd: 0.0,
        fechaRegistro: DateTime(2026, 4, 3),
      ),
    ];

    _productos = [
      const Producto(
        id: 'p00000001',
        cantidad: 10,
        nombre: 'Pantalon',
        marca: 'Generica',
        modelo: 'Casual',
        talla: 'M',
        precioUsd: 20.0,
        fotoUrl: 'https://lh3.googleusercontent.com/d/1_DRIVE_FILE_ID_PANTALON_CASUAL',
      ),
    ];

    _ventas = [
      Venta(
        id: 'v00000001',
        fecha: DateTime(2026, 4, 3),
        clienteId: 'c00000001',
        itemId: 'p00000001',
        cantidad: 1,
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        tipoPago: TipoPago.efectivo,
        comisionPagoMovilBs: 0.0,
        montoBs: 9480.0,
        montoUsd: 20.0,
        abonoUsd: 20.0,
        deudaUsd: 0.0,
        totalPagarUsd: 20.0,
        validacion: 'OK',
        estado: EstadoVenta.pagada,
      ),
    ];

    _comprasDivisas = [
      CompraDivisa(
        id: 'd00000001',
        fechaCompra: DateTime(2026, 4, 3),
        fechaEntrega: DateTime(2026, 4, 3),
        capitalUsd: 100.0,
        comisionBinanceUsd: 1.0,
        numeroOrden: 'ORD-2026-001',
        plataforma: 'Binance P2P',
        vendedor: 'CryptoTrader VE',
        tasaBcv: 474.0,
        tasaUsd: 480.0,
        validacion: 'OK',
      ),
    ];

    _resumenesDiarios = [
      ResumenDiario(
        fecha: DateTime(2026, 4, 3),
        nroVentas: 1,
        totalBs: 9480.0,
        totalUsd: 20.0,
        tasaBcv: 474.0,
        tasaUsd: 480.0,
        usdComprados: 100.0,
        usdVendidos: 20.0,
      ),
    ];

    _cuarentenas = [
      RegistroCuarentena(
        idRegistroOriginal: '3c82e14c',
        hojaOrigen: 'registro de ventas diarias',
        fechaDeteccion: DateTime.parse('2026-09-14T09:01:55.343995-04:00'),
        motivoCuarentena: 'Registro agregado insertado en tabla transaccional sin desglose de ítems',
        datosOriginalesJson: '{"NRO DE VENTAS DIARIAS": "20", "PAGO DEL CLIENTE EN BS": "0", "VALOR EN DOLARES": "30"}',
        estado: 'CONSOLIDADO',
        resolucion: 'Trasladado a hoja resumen_diario como métrica consolidada para fecha 2026-04-03.',
        hashEvidencia: '06191282aec0e96133e5e6a7ee87ae4e36fafd79bb70021f6c3a7e75b3621f79',
      ),
      RegistroCuarentena(
        idRegistroOriginal: 'c5fcc173',
        hojaOrigen: 'registro de compras de dolares',
        fechaDeteccion: DateTime.parse('2026-09-14T09:01:55.343995-04:00'),
        motivoCuarentena: 'Hoja erróneamente nombrada conteniendo venta de pantalón. monto_bs=0 para valor_usd=20',
        datosOriginalesJson: '{"CLIENTE": "neida", "PRODUCTO": "pantalon", "CANTIDAD": "1", "MONTO EN BS": "0", "VALOR EN DOLARES": "20"}',
        estado: 'CORREGIDO',
        resolucion: 'Normalizado 3FN: Cliente c00000001, Producto p00000001, Venta v00000001',
        hashEvidencia: '7d405513d81bcf69f714196f2f67d17e6cbf04142cd59614b1d54340ec807fdb',
      ),
    ];

    _auditLogs = [
      AuditLog(
        timestampIso8601: DateTime.parse('2026-09-14T09:01:55.343995-04:00'),
        usuario: 'Auditor Forense ISO',
        hoja: 'global',
        celda: 'A1',
        valorAnterior: 'SHA-256: 8c669061392782d04aaa4ef43ecbd227d8f8fb7d0c8af7572f3d0c33c224743d',
        valorNuevo: 'Backup generado (.xlsx, .csv x5, .json)',
        accion: 'seguridad_backup_previa',
        normaAplicada: 'ISO/IEC 27001 §8.13',
        observaciones: 'Respaldo íntegro tripartito en Backups/2026/ verificado',
      ),
      AuditLog(
        timestampIso8601: DateTime.parse('2026-09-14T09:01:55.343995-04:00'),
        usuario: 'Auditor Forense ISO',
        hoja: 'clientes',
        celda: 'A1:F2',
        valorAnterior: 'No existía entidad de clientes',
        valorNuevo: 'Creada hoja clientes con ID c00000001 y datos anonimizados',
        accion: 'creacion_entidad',
        normaAplicada: 'GDPR Art. 5 / NIST SP 800-53',
        observaciones: 'Teléfono E.164 +584120000001 y email regex compliant',
      ),
    ];

    _reportesMigracion = [
      const ReporteMigracion(
        metrica: 'Integridad Referencial (FKs)',
        valorEstado: '100% Conforme',
        normaAplicada: 'ISO 8000 §4.2',
        observaciones: '0 referencias huérfanas en clientes e inventario',
      ),
      const ReporteMigracion(
        metrica: 'Cumplimiento Formatos Internacionales',
        valorEstado: 'E.164 y ISO 8601',
        normaAplicada: 'RFC 4180 / ISO 8601',
        observaciones: 'Fechas estandarizadas en YYYY-MM-DD y teléfonos con prefijo de país',
      ),
      const ReporteMigracion(
        metrica: 'Seguridad y Cero Polling',
        valorEstado: 'Activo',
        normaAplicada: 'ISO/IEC 25010 / ISO 27001',
        observaciones: 'Actualizaciones bajo demanda manual sin temporizadores periódicos',
      ),
    ];

    _checklistIsos = [
      ChecklistISO(
        nro: 1,
        control: 'Backup verificado en 3 formatos (XLSX, CSV, JSON)',
        norma: 'ISO/IEC 27001 §8.13',
        estado: '☑',
        evidencia: 'Backups/2026/Estilo Neutral_BACKUP_FASE10',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
      ),
      ChecklistISO(
        nro: 2,
        control: 'Hash SHA-256 original registrado en bitácora',
        norma: 'NIST SP 800-53',
        estado: '☑',
        evidencia: 'audit_log!E2',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
      ),
      ChecklistISO(
        nro: 3,
        control: '0 encabezados duplicados en 9 hojas',
        norma: 'ISO 8000 §4.1',
        estado: '☑',
        evidencia: 'Hojas: clientes, inventario, ventas, compras_divisas, etc.',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
      ),
      ChecklistISO(
        nro: 4,
        control: 'Accesibilidad y Tap Targets mínimos 48x48',
        norma: 'WCAG 2.2 AA',
        estado: '☑',
        evidencia: 'AppButton, AppCard y controles interactivos',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
      ),
    ];
  }
}

/// Parser RFC 4180 robusto para archivos CSV con comas, saltos de línea y comillas.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  final currentField = StringBuffer();
  var currentRow = <String>[];
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final nextChar = (i + 1 < input.length) ? input[i + 1] : '';

    if (inQuotes) {
      if (char == '"') {
        if (nextChar == '"') {
          currentField.write('"');
          i++; // escapar comilla doble
        } else {
          inQuotes = false;
        }
      } else {
        currentField.write(char);
      }
    } else {
      if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && nextChar == '\n') {
          i++; // omitir CRLF
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        if (currentRow.isNotEmpty && (currentRow.length > 1 || currentRow.first.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
      } else {
        currentField.write(char);
      }
    }
  }

  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentField.toString().trim());
    if (currentRow.isNotEmpty && (currentRow.length > 1 || currentRow.first.isNotEmpty)) {
      rows.add(currentRow);
    }
  }

  return rows;
}
