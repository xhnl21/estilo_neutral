import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';
import '../../models/models.dart';
import '../storage/secure_token_storage.dart';
import 'sheets_config.dart';

/// Servicio centralizado de datos y sincronización para las 10 hojas de Google Sheets.
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

  // Colecciones en memoria para las 11 hojas
  List<Cliente> _clientes = [];
  List<Producto> _productos = [];
  List<Venta> _ventas = [];
  List<VentaItem> _ventaItems = [];
  List<Abono> _abonos = [];
  List<CompraDivisa> _comprasDivisas = [];
  List<ResumenDiario> _resumenesDiarios = [];
  List<RegistroCuarentena> _cuarentenas = [];
  List<AuditLog> _auditLogs = [];
  List<ReporteMigracion> _reportesMigracion = [];
  List<ChecklistISO> _checklistIsos = [];
  List<Seguridad> _seguridad = [];
  List<Usuario> _usuarios = [];
  List<Organizacion> _organizaciones = [];
  List<UsuarioOrganizacion> _usuarioOrganizaciones = [];
  List<MetodoPago> _metodosPago = [
    const MetodoPago(id: 'mp00000001', nombre: 'Efectivo', status: true),
    const MetodoPago(id: 'mp00000002', nombre: 'Pago Movil', status: true),
    const MetodoPago(id: 'mp00000003', nombre: 'Transferencia', status: true),
    const MetodoPago(id: 'mp00000004', nombre: 'Zelle', status: true),
    const MetodoPago(id: 'mp00000005', nombre: 'Binance', status: true),
    const MetodoPago(id: 'mp00000006', nombre: 'Otro', status: true),
  ];
  List<TasaRegistro> _tasas = [];
  List<MonedaOrganizacion> _monedasOrganizacion = [];

  /// Organización actualmente activa en la sesión (resuelta tras el login mediante
  /// la hoja de relación "usuario_organizacion"). Las 9 hojas de negocio (todas
  /// menos [usuarios], [organizaciones] y [seguridad]) se filtran client-side por
  /// esta organización.
  String? _currentOrganizacionId;
  String? get currentOrganizacionId => _currentOrganizacionId;

  /// Establece la organización activa (o `null` para limpiar, p.ej. al cerrar sesión).
  void setCurrentOrganizacion(String? organizacionId) {
    _currentOrganizacionId = organizacionId;
    notifyListeners();
  }

  /// Usuario actualmente autenticado (email normalizado). A diferencia de la
  /// organización, [seguridad] se filtra por este email, no por
  /// [_currentOrganizacionId] — el método de autenticación adicional es una
  /// preferencia por usuario, no por organización (ver `Seguridad`).
  String? _currentUsuarioEmail;
  String? get currentUsuarioEmail => _currentUsuarioEmail;

  /// Establece el usuario activo (o `null` para limpiar, p.ej. al cerrar sesión).
  void setCurrentUsuario(String? email) {
    _currentUsuarioEmail = email?.trim().toLowerCase();
    notifyListeners();
  }

  /// `true` solo si la última sincronización pudo leer la hoja
  /// "organizaciones" con su encabezado nuevo (`id`, `nombre`) — es decir, si
  /// el Sheet real ya tiene la migración de esquema multi-organización (ver
  /// docs/google/multi-organizacion.md). Mientras sea `false`, las vistas de
  /// Usuarios/Organizaciones deben bloquear create/update/delete: de lo
  /// contrario seguirían operando sobre los datos semilla en memoria (o,
  /// peor, sobre columnas corridas del esquema viejo) en vez de la hoja real.
  bool _schemaMultiOrgListo = false;
  bool get schemaMultiOrgListo => _schemaMultiOrgListo;

  /// Resuelve la organización a la que pertenece [email] a través de la hoja
  /// de relación "usuario_organizacion" (relación 1:N organización→usuarios).
  /// Devuelve `null` si el usuario no tiene ninguna membresía registrada.
  String? organizacionIdForUsuario(String email) {
    final normalized = email.trim().toLowerCase();
    for (final rel in _usuarioOrganizaciones) {
      if (rel.usuarioEmail == normalized) return rel.organizacionId;
    }
    return null;
  }

  bool _matchesCurrentOrg(String organizacionId) =>
      _currentOrganizacionId != null && organizacionId == _currentOrganizacionId;

  List<Cliente> get clientes =>
      List.unmodifiable(_clientes.where((c) => _matchesCurrentOrg(c.organizacionId)));
  List<Producto> get productos =>
      List.unmodifiable(_productos.where((p) => _matchesCurrentOrg(p.organizacionId)));
  List<Venta> get ventas =>
      List.unmodifiable(_ventas.where((v) => _matchesCurrentOrg(v.organizacionId)));

  /// Ítems (renglones) de todas las ventas/facturas. No tienen su propia
  /// `organizacion_id` — pertenecen a la organización de su venta — usar
  /// [itemsDeVenta] para obtener los de una factura puntual ya filtrada.
  List<VentaItem> get ventaItems => List.unmodifiable(_ventaItems);

  /// Ítems de la factura [ventaId], en el orden en que se cargaron.
  List<VentaItem> itemsDeVenta(String ventaId) =>
      List.unmodifiable(_ventaItems.where((vi) => vi.ventaId == ventaId));

  /// Historial completo de abonos de todas las facturas. Igual que
  /// [ventaItems], no tiene su propia `organizacion_id` — usar [abonosDeVenta]
  /// para los de una factura puntual.
  List<Abono> get abonos => List.unmodifiable(_abonos);

  /// Abonos de la factura [ventaId], ordenados por fecha de registro.
  List<Abono> abonosDeVenta(String ventaId) =>
      List.unmodifiable(_abonos.where((a) => a.ventaId == ventaId));

  List<CompraDivisa> get comprasDivisas =>
      List.unmodifiable(_comprasDivisas.where((c) => _matchesCurrentOrg(c.organizacionId)));
  List<ResumenDiario> get resumenesDiarios =>
      List.unmodifiable(_resumenesDiarios.where((r) => _matchesCurrentOrg(r.organizacionId)));
  List<RegistroCuarentena> get cuarentenas =>
      List.unmodifiable(_cuarentenas.where((c) => _matchesCurrentOrg(c.organizacionId)));
  List<AuditLog> get auditLogs =>
      List.unmodifiable(_auditLogs.where((a) => _matchesCurrentOrg(a.organizacionId)));
  List<ReporteMigracion> get reportesMigracion =>
      List.unmodifiable(_reportesMigracion.where((r) => _matchesCurrentOrg(r.organizacionId)));
  List<ChecklistISO> get checklistIsos =>
      List.unmodifiable(_checklistIsos.where((c) => _matchesCurrentOrg(c.organizacionId)));

  /// Directorio de usuarios (entidad Usuario). No se filtra por organización:
  /// la membresía a una organización vive en [usuarioOrganizaciones], no acá.
  List<Usuario> get usuarios => List.unmodifiable(_usuarios);

  /// Directorio de organizaciones (entidad Organización). Transversal, es la
  /// fuente de verdad de qué organizaciones existen.
  List<Organizacion> get organizaciones => List.unmodifiable(_organizaciones);

  /// Relación usuario↔organización (1:N — una organización, muchos usuarios).
  /// Transversal, es la propia lista de membresía.
  List<UsuarioOrganizacion> get usuarioOrganizaciones => List.unmodifiable(_usuarioOrganizaciones);

  /// Catálogo de métodos de pago gobernado por la hoja "metodo pago".
  List<MetodoPago> get metodosPago => List.unmodifiable(_metodosPago);

  /// Métodos de pago activos (status == true) disponibles para usar en transacciones.
  List<MetodoPago> get metodosPagoActivos =>
      List.unmodifiable(_metodosPago.where((m) => m.status));

  /// Historial de tasas (hoja "tasas") — una fila por moneda/fecha/fuente,
  /// alimentada por el módulo Tasas (fuente='bcv') o por las organizaciones
  /// que fijan su propia tasa (fuente='manual').
  List<TasaRegistro> get tasas => List.unmodifiable(_tasas);

  /// Resuelve una tasa por su ID — el JOIN lógico que usa la UI para
  /// mostrar el valor/origen real de un `ventas.tasa_id`/`abonos.tasa_id`
  /// sin que esas hojas dupliquen el dato.
  TasaRegistro? tasaPorId(String tasaId) => _tasas.where((t) => t.id == tasaId).firstOrNull;

  /// La tasa BCV automática más reciente para [moneda] ('USD'/'EUR'), o
  /// null si el módulo Tasas todavía no tiene datos para esa moneda.
  TasaRegistro? tasaBcvVigente(String moneda) {
    final candidatas = _tasas.where((t) => t.fuente == 'bcv' && t.moneda == moneda && t.organizacionId.isEmpty);
    if (candidatas.isEmpty) return null;
    return candidatas.reduce((a, b) => a.fecha.isAfter(b.fecha) ? a : b);
  }

  /// La tasa manual fijada por la organización [organizacionId], o null si
  /// no configuró ninguna.
  TasaRegistro? tasaManualOrganizacion(String organizacionId) =>
      _tasas.where((t) => t.fuente == 'manual' && t.organizacionId == organizacionId).firstOrNull;

  /// La organización actualmente activa (según [_currentOrganizacionId]),
  /// o null si todavía no se resolvió ninguna.
  Organizacion? get organizacionActual =>
      _organizaciones.where((o) => o.id == _currentOrganizacionId).firstOrNull;

  /// Historial de selección de moneda base por organización (hoja
  /// "moneda_organizacion").
  List<MonedaOrganizacion> get monedasOrganizacion => List.unmodifiable(_monedasOrganizacion);

  /// La moneda base seleccionada por [organizacionId] ('USD'/'EUR') — 'USD'
  /// por defecto si esa organización todavía no eligió ninguna.
  String monedaOrganizacion(String organizacionId) =>
      _monedasOrganizacion.where((m) => m.organizacionId == organizacionId).firstOrNull?.moneda ?? 'USD';

  /// La tasa BCV automática vigente en la moneda base configurada por la
  /// organización actual — null si el módulo Tasas todavía no tiene datos.
  TasaRegistro? get tasaVigenteEnMonedaBase => tasaBcvVigente(monedaOrganizacion(_currentOrganizacionId ?? ''));

  /// % de cambio de [tasa] contra el registro anterior de la misma
  /// moneda+fuente+organización. Se calcula al vuelo — no se almacena, para
  /// no guardar un dato derivado que podría desincronizarse del histórico
  /// real si se corrige una tasa pasada.
  double cambioPctTasa(TasaRegistro tasa) {
    final anteriores = _tasas.where((t) =>
        t.moneda == tasa.moneda &&
        t.fuente == tasa.fuente &&
        t.organizacionId == tasa.organizacionId &&
        t.fecha.isBefore(tasa.fecha)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    if (anteriores.isEmpty || anteriores.first.valor == 0) return 0.0;
    return ((tasa.valor - anteriores.first.valor) / anteriores.first.valor) * 100;
  }

  /// Resuelve qué tasa aplicar a un abono según lo que eligió el usuario: la
  /// manual de la organización actual (si la pidió y existe una) o la BCV
  /// automática vigente en la moneda base. Devuelve el `tasa_id` (FK) a
  /// guardar — nunca un valor numérico ni el origen sueltos.
  String _resolverTasaAplicada(bool usarTasaManual) {
    if (usarTasaManual) {
      final manual = tasaManualOrganizacion(_currentOrganizacionId ?? '');
      if (manual != null) return manual.id;
    }
    return tasaVigenteEnMonedaBase?.id ?? '';
  }

  /// Configuración de seguridad del usuario actual. Si el usuario activo aún
  /// no tiene fila propia en la hoja "seguridad", se devuelven los valores
  /// por defecto (sin mutar el estado en memoria).
  Seguridad get seguridad => _seguridad.firstWhere(
        (s) => _currentUsuarioEmail != null && s.usuarioEmail == _currentUsuarioEmail,
        orElse: () => Seguridad(usuarioEmail: _currentUsuarioEmail ?? ''),
      );

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

  /// Carga bajo demanda de las 10 hojas desde Google Sheets mediante el endpoint GViz
  Future<void> fetchAllSheets({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    int successCount = 0;
    final errors = <String>[];

    Future<void> safeFetch(
      String name,
      void Function(List<List<String>>) parser, {
      List<String>? expectedHeaders,
      VoidCallback? onValidHeader,
    }) async {
      try {
        await _fetchSheet(name, parser, expectedHeaders: expectedHeaders);
        successCount++;
        onValidHeader?.call();
      } catch (e) {
        errors.add('$name: $e');
        debugPrint('Error fetching sheet $name: $e');
      }
    }

    _schemaMultiOrgListo = false;

    try {
      await Future.wait([
        safeFetch('clientes', _parseClientes),
        safeFetch('inventario', _parseProductos),
        // "ventas" es el header de la factura (esquema nuevo, ver
        // docs/google/multi-organizacion.md) — se valida el encabezado por la
        // misma razón que seguridad/usuarios/organizaciones.
        safeFetch('ventas', _parseVentas, expectedHeaders: const [
          'id', 'fecha', 'cliente_id', 'tasa_bcv', 'tasa_usd', 'tipo_pago',
          'comision_pago_movil_bs', 'monto_bs', 'monto_usd', 'abono_usd',
          'deuda_usd', 'total_pagar_usd', 'validacion', 'estado', 'organizacion_id',
        ]),
        safeFetch(
          'venta_items',
          _parseVentaItems,
          expectedHeaders: const ['id', 'venta_id', 'item_id', 'cantidad', 'precio_usd', 'subtotal_usd'],
        ),
        // Historial de abonos (una fila por pago parcial, con su propio
        // método de pago) — relación 1:N venta→abonos, igual que venta_items.
        safeFetch(
          'abonos',
          _parseAbonos,
          expectedHeaders: const ['id', 'venta_id', 'fecha', 'monto', 'metodo_pago', 'tasa_bcv', 'tasa_fuente'],
        ),
        safeFetch('compras_divisas', _parseCompras),
        safeFetch('resumen_diario', _parseResumenes),
        safeFetch('cuarentena', _parseCuarentenas),
        safeFetch('audit_log', _parseAuditLogs),
        safeFetch('reporte_migracion', _parseReportes),
        safeFetch('checklist_iso', _parseChecklists),
        // Estos 4 tienen esquema nuevo (ver docs/google/multi-organizacion.md):
        // se valida el encabezado para no aceptar filas de otra hoja si el
        // Sheet real todavía no fue migrado.
        safeFetch('seguridad', _parseSeguridad, expectedHeaders: const [
          'biometrico', 'desbloqueo_facial', 'dos_factores', 'usuario_email',
        ]),
        safeFetch('usuarios', _parseUsuarios, expectedHeaders: const ['id', 'email', 'nombre']),
        safeFetch(
          'organizaciones',
          _parseOrganizaciones,
          expectedHeaders: const ['id', 'nombre'],
          onValidHeader: () => _schemaMultiOrgListo = true,
        ),
        safeFetch(
          'usuario_organizacion',
          _parseUsuarioOrganizaciones,
          expectedHeaders: const ['usuario_email', 'organizacion_id'],
        ),
        safeFetch(
          'metodo pago',
          _parseMetodosPago,
          expectedHeaders: const ['id', 'nombre', 'status'],
        ),
        // Una fila por moneda/fecha/fuente (3FN — ver TasaRegistro). Las
        // filas fuente='bcv' las alimenta el módulo Tasas en Apps Script
        // (trigger diario); las fuente='manual' las crea/actualiza esta
        // misma app cuando una organización fija su propia tasa.
        safeFetch(
          'tasas',
          _parseTasas,
          expectedHeaders: const ['id', 'fecha', 'moneda', 'valor', 'fuente', 'organizacion_id'],
        ),
        // Moneda base seleccionada por organización — separada en su
        // propia hoja (no una columna en "organizaciones") para no
        // duplicar la misma fuente de verdad en dos lugares.
        safeFetch(
          'moneda_organizacion',
          _parseMonedasOrganizacion,
          expectedHeaders: const ['id', 'organizacion_id', 'moneda', 'actualizado_en'],
        ),
      ]);

      if (successCount > 0) {
        _lastSync = DateTime.now();
        _errorMessage = null;
      } else {
        final isPrivateDoc = errors.any((e) => e.contains('401') || e.contains('Privado'));
        if (isPrivateDoc) {
          _errorMessage = 'Documento privado: En Google Sheets haz clic en "Compartir" y selecciona "Cualquier persona con el enlace".';
          Logger.error(
            'SheetsDataService: Acceso no autorizado (HTTP 401). El documento de Google Sheets está en modo "Restringido". '
            'Para permitir lectura pública por GViz, en tu hoja de Google Sheets ve a Compartir > Acceso general > '
            'cambia de "Restringido" a "Cualquier persona que tenga el vínculo" (Lector).',
          );
        } else {
          _errorMessage = 'Sin conexión con Google Sheets: operando con caché local.';
        }
      }
    } catch (e) {
      _errorMessage = 'Sin conexión con Google Sheets: operando con caché local.';
      debugPrint('SheetsDataService fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSheet(
    String sheetName,
    void Function(List<List<String>>) parser, {
    List<String>? expectedHeaders,
  }) async {
    final cleanId = SheetsConfig.extractSpreadsheetId(spreadsheetId);
    final url = Uri.parse(
      'https://docs.google.com/spreadsheets/d/$cleanId/gviz/tq?tqx=out:csv&sheet=$sheetName',
    );
    final response = await _httpClient.get(url, headers: {
      'User-Agent': 'Flutter-EstiloNeutral/1.0',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      if (response.body.contains('<html') || response.body.contains('ServiceLogin')) {
        throw Exception('HTTP 401: Documento Privado');
      }
      final rows = parseCsv(response.body);
      if (rows.isEmpty) return;

      // Si se pasan encabezados esperados, se valida la fila 1 antes de parsear.
      // El endpoint GViz puede devolver silenciosamente los datos de OTRA hoja
      // (por ejemplo, si `sheetName` todavía no existe en el Sheet real) — sin
      // esto, esas filas ajenas se interpretarían como datos válidos de
      // `sheetName`, mezclando columnas de una hoja con las de otra.
      if (expectedHeaders != null) {
        final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
        final matches = header.length >= expectedHeaders.length &&
            List.generate(
              expectedHeaders.length,
              (i) => header[i] == expectedHeaders[i].toLowerCase(),
            ).every((ok) => ok);
        if (!matches) {
          throw Exception(
            'La hoja "$sheetName" no tiene el encabezado esperado ${expectedHeaders.join("/")} '
            '(encontrado: ${header.join("/")}) — ¿falta migrar el esquema del Sheet?',
          );
        }
      }

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

  void _parseVentaItems(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows.map((r) => VentaItem.fromRow(r)).toList();
    final localPending = _ventaItems.where((local) => !cloud.any((vi) => vi.id == local.id)).toList();
    _ventaItems = [...cloud, ...localPending];
  }

  void _parseAbonos(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows.map((r) => Abono.fromRow(r)).toList();
    final localPending = _abonos.where((local) => !cloud.any((a) => a.id == local.id)).toList();
    _abonos = [...cloud, ...localPending];
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

  void _parseSeguridad(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _seguridad = rows.map((r) => Seguridad.fromRow(r)).toList();
  }

  void _parseOrganizaciones(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _organizaciones = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => Organizacion.fromRow(r))
        .toList();
  }

  void _parseUsuarioOrganizaciones(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _usuarioOrganizaciones = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => UsuarioOrganizacion.fromRow(r))
        .toList();
  }

  void _parseUsuarios(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _usuarios = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => Usuario.fromRow(r))
        .toList();
  }

  void _parseMetodosPago(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _metodosPago = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => MetodoPago.fromRow(r))
        .toList();
  }

  void _parseTasas(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => TasaRegistro.fromRow(r))
        .toList();
    final localPending = _tasas.where((local) => !cloud.any((t) => t.id == local.id)).toList();
    _tasas = [...cloud, ...localPending];
  }

  void _parseMonedasOrganizacion(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => MonedaOrganizacion.fromRow(r))
        .toList();
    final localPending = _monedasOrganizacion.where((local) => !cloud.any((m) => m.id == local.id)).toList();
    _monedasOrganizacion = [...cloud, ...localPending];
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
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _auditLogs.insert(0, log);
  }

  /// Sincroniza de forma asíncrona la acción con la Web App de Google Apps Script (Opción A)
  Future<bool> _postToAppsScript(Map<String, dynamic> payload) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      Logger.warning(
        'SheetsDataService: APPS_SCRIPT_URL no está configurada en variables de entorno (.env). El cambio se guardó localmente.',
      );
      return false;
    }

    if (url.contains('docs.google.com/spreadsheets')) {
      Logger.error(
        'SheetsDataService Error de Configuración: APPS_SCRIPT_URL tiene una URL de visualización de Google Sheets ($url). '
        'Google Sheets rechaza peticiones POST directas con error HTTP 405 (Method Not Allowed). '
        'Para guardar en el documento de Google Sheets, se requiere desplegar google_apps_script.js como Web App '
        'y colocar la URL de ejecución (ej. https://script.google.com/macros/s/.../exec) en tu archivo .env.',
      );
      return false;
    }

    try {
      final sheet = payload['sheet'] ?? 'desconocida';
      final action = payload['action'] ?? 'desconocida';
      Logger.api('POST $url [Hoja: $sheet, Acción: $action]', isRequest: true);
      Logger.object('Payload Apps Script', payload);

      var response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      // Google Apps Script responde con 302 Found redirigiendo a googleusercontent.com
      if ((response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307) &&
          response.headers.containsKey('location')) {
        final redirectUrl = response.headers['location']!;
        Logger.api('Siguiendo redirección de Apps Script: $redirectUrl', isRequest: true);
        try {
          response = await _httpClient.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 15));
        } catch (_) {
          // Si el redirect falla por red o timeout pero ya se recibió 302 de Apps Script, la acción ya fue procesada
        }
      }

      Logger.api('${response.statusCode} - Respuesta Apps Script: ${response.body}', isRequest: false);

      final isOk = response.statusCode == 200 || response.statusCode == 302;
      if (isOk) {
        Logger.success('SheetsDataService: Sincronización exitosa en Google Sheets (Hoja: $sheet, Acción: $action).');
        return true;
      } else {
        Logger.error(
          'SheetsDataService: Falló sincronización con Google Sheets. Código HTTP: ${response.statusCode}. Respuesta: ${response.body}',
        );
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('SheetsDataService: Excepción al conectar con Apps Script', e, stackTrace);
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
      var response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'upload_image',
          'fileName': fileName,
          'mimeType': mimeType,
          'base64Data': base64Data,
        }),
      ).timeout(const Duration(seconds: 30));

      if ((response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307) &&
          response.headers.containsKey('location')) {
        final redirectUrl = response.headers['location']!;
        try {
          response = await _httpClient.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 30));
        } catch (_) {}
      }

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
    final stamped = Cliente(
      id: cliente.id,
      nombre: cliente.nombre,
      telefono: cliente.telefono,
      email: cliente.email,
      saldoDeudaUsd: cliente.saldoDeudaUsd,
      fechaRegistro: cliente.fechaRegistro,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    Logger.info('SheetsDataService: Registrando nuevo cliente localmente: ${stamped.id} (${stamped.nombre})');
    _clientes.add(stamped);
    _logAudit(
      hoja: 'clientes',
      celda: 'A${_clientes.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.id} (${stamped.nombre})',
      accion: 'creacion_cliente',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Alta de cliente con teléfono ${stamped.telefono}',
    );
    notifyListeners();
    Logger.info('SheetsDataService: Despachando inserción a Google Sheets para cliente ${stamped.id}...');
    final synced = await _postToAppsScript({
      'action': 'create',
      'sheet': 'clientes',
      'data': stamped.toMap(),
    });
    if (synced) {
      Logger.success('SheetsDataService: Cliente ${stamped.id} sincronizado exitosamente en Google Sheets.');
    } else {
      Logger.warning('SheetsDataService: Cliente ${stamped.id} guardado localmente pero no sincronizado con Google Sheets.');
    }
    return synced;
  }

  void updateCliente(Cliente cliente) {
    Logger.info('SheetsDataService: Actualizando cliente localmente: ${cliente.id} (${cliente.nombre})');
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
    Logger.warning('SheetsDataService: Solicitada baja de cliente con ID: $id');
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
    final stamped = Producto(
      id: producto.id,
      cantidad: producto.cantidad,
      nombre: producto.nombre,
      marca: producto.marca,
      modelo: producto.modelo,
      talla: producto.talla,
      precioUsd: producto.precioUsd,
      fotoUrl: producto.fotoUrl,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _productos.add(stamped);
    _logAudit(
      hoja: 'inventario',
      celda: 'A${_productos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.id} (${stamped.nombre})',
      accion: 'creacion_producto',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Nuevo producto en inventario. Stock inicial: ${stamped.cantidad}',
    );
    _postToAppsScript({
      'action': 'create',
      'sheet': 'inventario',
      'data': stamped.toMap(),
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
        organizacionId: old.organizacionId,
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

  String get nextVentaItemId {
    final maxId = _ventaItems.fold<int>(0, (prev, vi) {
      final numStr = vi.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'vi${(maxId + 1).toString().padLeft(8, '0')}';
  }

  String get nextAbonoId {
    final maxId = _abonos.fold<int>(0, (prev, a) {
      final numStr = a.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'ab${(maxId + 1).toString().padLeft(8, '0')}';
  }

  /// Registra una factura completa: una venta (header) con uno o más ítems.
  /// [items] es la lista de productos del carrito, cada uno con la cantidad
  /// y el precio unitario a cobrar (capturado en el momento de la venta).
  Future<bool> addVenta({
    required String clienteId,
    required List<({String productoId, int cantidad, double precioUsd})> items,
    required String metodoPagoId,
    double comisionPagoMovilBs = 0.0,
    required double abonoUsd,
    bool usarTasaManual = false,
  }) async {
    assert(items.isNotEmpty, 'Una factura necesita al menos un ítem');

    // La tasa Bs./USD de la factura ya no se tipea a mano: es la misma que
    // se resuelve para el abono (BCV automática del día, o la manual de la
    // organización si el usuario la eligió) — una sola fuente de verdad
    // para toda la transacción, no dos números sueltos por venta.
    final tasaBcv = tasaPorId(_resolverTasaAplicada(usarTasaManual))?.valor ?? 0.0;

    final ventaId = nextVentaId;
    final montoUsd = items.fold<double>(0.0, (sum, it) => sum + it.cantidad * it.precioUsd);
    final montoBs = montoUsd * tasaBcv;
    final deudaUsd = (montoUsd - abonoUsd).clamp(0.0, double.infinity);
    final estado = deudaUsd <= 0 ? EstadoVenta.pagada : EstadoVenta.pendiente;

    final venta = Venta(
      id: ventaId,
      fecha: DateTime.now(),
      clienteId: clienteId,
      tasaBcv: tasaBcv,
      tasaUsd: tasaBcv,
      metodoPagoId: metodoPagoId,
      comisionPagoMovilBs: comisionPagoMovilBs,
      montoBs: montoBs,
      montoUsd: montoUsd,
      abonoUsd: abonoUsd,
      deudaUsd: deudaUsd,
      totalPagarUsd: montoUsd,
      validacion: 'OK',
      estado: estado,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _ventas.insert(0, venta);

    final nuevosItems = <VentaItem>[];
    for (final it in items) {
      final ventaItem = VentaItem(
        id: nextVentaItemId,
        ventaId: ventaId,
        itemId: it.productoId,
        cantidad: it.cantidad,
        precioUsd: it.precioUsd,
        subtotalUsd: it.cantidad * it.precioUsd,
      );
      _ventaItems.insert(0, ventaItem);
      nuevosItems.add(ventaItem);
      adjustStock(it.productoId, -it.cantidad);
    }

    // Ajustar saldo de deuda del cliente si queda saldo pendiente
    if (venta.deudaUsd > 0) {
      final cIdx = _clientes.indexWhere((c) => c.id == clienteId);
      if (cIdx != -1) {
        final c = _clientes[cIdx];
        _clientes[cIdx] = Cliente(
          id: c.id,
          nombre: c.nombre,
          telefono: c.telefono,
          email: c.email,
          saldoDeudaUsd: c.saldoDeudaUsd + venta.deudaUsd,
          fechaRegistro: c.fechaRegistro,
          organizacionId: c.organizacionId,
        );
      }
    }

    _logAudit(
      hoja: 'ventas',
      celda: 'A${_ventas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${venta.id} por USD ${venta.totalPagarUsd.toStringAsFixed(2)} (${items.length} ítems)',
      accion: 'creacion_venta',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Factura registrada a cliente $clienteId',
    );

    // El abono inicial (si lo hay) es, en sí mismo, el primer pago de la
    // factura — se registra como el primer renglón del historial de abonos,
    // no solo como un número acumulado en el header.
    Abono? abonoInicial;
    if (abonoUsd > 0) {
      abonoInicial = Abono(
        id: nextAbonoId,
        ventaId: ventaId,
        fecha: venta.fecha,
        monto: abonoUsd,
        metodoPagoId: metodoPagoId,
        tasaId: _resolverTasaAplicada(usarTasaManual),
      );
      _abonos.insert(0, abonoInicial);
    }

    // Header + ítems + abono inicial se sincronizan en paralelo (no
    // secuencialmente): con varios ítems, esperar cada POST uno tras otro
    // sumaría varios segundos de latencia real innecesarios.
    final resultados = await Future.wait([
      _postToAppsScript({'action': 'create', 'sheet': 'ventas', 'data': venta.toMap()}),
      for (final vi in nuevosItems)
        _postToAppsScript({'action': 'create', 'sheet': 'venta_items', 'data': vi.toMap()}),
      if (abonoInicial != null)
        _postToAppsScript({'action': 'create', 'sheet': 'abonos', 'data': abonoInicial.toMap()}),
    ]);
    notifyListeners();
    return resultados.every((ok) => ok);
  }

  /// Registra un abono (pago parcial) a una factura: crea una fila propia en
  /// el historial de abonos con su método de pago, y actualiza el total
  /// abonado/deuda/estado del header. El `metodoPago` de la factura (el de
  /// la venta original) no se toca — el método de cada pago individual vive
  /// en su propia fila de [abonos], no se pisa el de la venta.
  Future<bool> registrarAbono(
    String ventaId,
    double montoAbono, {
    required String metodoPagoId,
    bool usarTasaManual = false,
  }) async {
    final index = _ventas.indexWhere((v) => v.id == ventaId);
    if (index == -1) return false;

    final old = _ventas[index];
    final nuevoAbono = old.abonoUsd + montoAbono;
    final nuevaDeuda = (old.totalPagarUsd - nuevoAbono).clamp(0.0, double.infinity);
    final nuevoEstado = nuevaDeuda == 0 ? EstadoVenta.pagada : EstadoVenta.pendiente;

    _ventas[index] = Venta(
      id: old.id,
      fecha: old.fecha,
      clienteId: old.clienteId,
      tasaBcv: old.tasaBcv,
      tasaUsd: old.tasaUsd,
      metodoPagoId: old.metodoPagoId,
      comisionPagoMovilBs: old.comisionPagoMovilBs,
      montoBs: old.montoBs,
      montoUsd: old.montoUsd,
      abonoUsd: nuevoAbono,
      deudaUsd: nuevaDeuda,
      totalPagarUsd: old.totalPagarUsd,
      validacion: 'OK',
      estado: nuevoEstado,
      organizacionId: old.organizacionId,
    );

    final abono = Abono(
      id: nextAbonoId,
      ventaId: ventaId,
      fecha: DateTime.now(),
      monto: montoAbono,
      metodoPagoId: metodoPagoId,
      tasaId: _resolverTasaAplicada(usarTasaManual),
    );
    _abonos.insert(0, abono);

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
        organizacionId: c.organizacionId,
      );
    }

    final nombreMetodo = metodoPagoNombre(metodoPagoId);
    _logAudit(
      hoja: 'ventas',
      celda: 'J${index + 2}',
      valorAnterior: 'Deuda: ${old.deudaUsd}',
      valorNuevo: 'Abono +$montoAbono ($nombreMetodo) -> Deuda: $nuevaDeuda',
      accion: 'registro_abono',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Abono de USD $montoAbono vía $nombreMetodo a venta $ventaId. Estado: ${nuevoEstado.name}',
    );

    final resultados = await Future.wait([
      _postToAppsScript({
        'action': 'update',
        'sheet': 'ventas',
        'id': ventaId,
        'data': _ventas[index].toMap(),
      }),
      _postToAppsScript({'action': 'create', 'sheet': 'abonos', 'data': abono.toMap()}),
    ]);
    notifyListeners();
    return resultados.every((ok) => ok);
  }

  /// Anula una factura completa: elimina la venta (header), todos sus ítems,
  /// y repone el stock que esos ítems habían descontado (espejo de [addVenta]).
  Future<void> deleteVenta(String id) async {
    final index = _ventas.indexWhere((v) => v.id == id);
    if (index == -1) return;

    final old = _ventas.removeAt(index);
    final items = _ventaItems.where((vi) => vi.ventaId == id).toList();
    _ventaItems.removeWhere((vi) => vi.ventaId == id);
    final abonosVenta = _abonos.where((a) => a.ventaId == id).toList();
    _abonos.removeWhere((a) => a.ventaId == id);

    for (final vi in items) {
      adjustStock(vi.itemId, vi.cantidad);
    }

    _logAudit(
      hoja: 'ventas',
      celda: 'A${index + 2}',
      valorAnterior: 'Venta ${old.id}',
      valorNuevo: 'ANULADA/ELIMINADA',
      accion: 'anulacion_venta',
      norma: 'ISO 8000',
      observaciones: 'Venta $id anulada (${items.length} ítems repuestos a inventario, ${abonosVenta.length} abonos eliminados)',
    );

    await Future.wait([
      _postToAppsScript({'action': 'delete', 'sheet': 'ventas', 'id': id}),
      for (final vi in items) _postToAppsScript({'action': 'delete', 'sheet': 'venta_items', 'id': vi.id}),
      for (final a in abonosVenta) _postToAppsScript({'action': 'delete', 'sheet': 'abonos', 'id': a.id}),
    ]);
    notifyListeners();
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
    final stamped = CompraDivisa(
      id: compra.id,
      fechaCompra: compra.fechaCompra,
      fechaEntrega: compra.fechaEntrega,
      capitalUsd: compra.capitalUsd,
      comisionBinanceUsd: compra.comisionBinanceUsd,
      numeroOrden: compra.numeroOrden,
      plataforma: compra.plataforma,
      vendedor: compra.vendedor,
      tasaBcv: compra.tasaBcv,
      tasaUsd: compra.tasaUsd,
      validacion: compra.validacion,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _comprasDivisas.insert(0, stamped);
    _logAudit(
      hoja: 'compras_divisas',
      celda: 'A${_comprasDivisas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.id}: USD ${stamped.capitalUsd}',
      accion: 'registro_compra_divisa',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Compra cambiaria en ${stamped.plataforma} por ${stamped.vendedor}',
    );
    _postToAppsScript({
      'action': 'create',
      'sheet': 'compras_divisas',
      'data': stamped.toMap(),
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
    final stamped = ResumenDiario(
      fecha: resumen.fecha,
      nroVentas: resumen.nroVentas,
      totalBs: resumen.totalBs,
      totalUsd: resumen.totalUsd,
      tasaBcv: resumen.tasaBcv,
      tasaUsd: resumen.tasaUsd,
      usdComprados: resumen.usdComprados,
      usdVendidos: resumen.usdVendidos,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    final existingIdx = _resumenesDiarios.indexWhere((r) => r.fecha == stamped.fecha);
    if (existingIdx != -1) {
      _resumenesDiarios[existingIdx] = stamped;
    } else {
      _resumenesDiarios.insert(0, stamped);
    }
    _logAudit(
      hoja: 'resumen_diario',
      celda: 'A${_resumenesDiarios.length + 1}',
      valorAnterior: 'null',
      valorNuevo: 'Cierre ${stamped.fecha}: USD ${stamped.totalUsd}',
      accion: 'cierre_diario',
      norma: 'COBIT 2019 / ISO 27001',
      observaciones: 'Registro de balance diario para ${stamped.fecha}',
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
    final stamped = RegistroCuarentena(
      idRegistroOriginal: item.idRegistroOriginal,
      hojaOrigen: item.hojaOrigen,
      fechaDeteccion: item.fechaDeteccion,
      motivoCuarentena: item.motivoCuarentena,
      datosOriginalesJson: item.datosOriginalesJson,
      estado: item.estado,
      resolucion: item.resolucion,
      hashEvidencia: item.hashEvidencia,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _cuarentenas.insert(0, stamped);
    _logAudit(
      hoja: 'cuarentena',
      celda: 'A${_cuarentenas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.idRegistroOriginal} (${stamped.motivoCuarentena})',
      accion: 'ingreso_cuarentena',
      norma: 'COBIT 2019 DSS05',
      observaciones: 'Anomalía aislada desde hoja ${stamped.hojaOrigen}',
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
    final stamped = AuditLog(
      timestampIso8601: log.timestampIso8601,
      usuario: log.usuario,
      hoja: log.hoja,
      celda: log.celda,
      valorAnterior: log.valorAnterior,
      valorNuevo: log.valorNuevo,
      accion: log.accion,
      normaAplicada: log.normaAplicada,
      observaciones: log.observaciones,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _auditLogs.insert(0, stamped);
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
        organizacionId: old.organizacionId,
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
    final stamped = ReporteMigracion(
      metrica: rep.metrica,
      valorEstado: rep.valorEstado,
      normaAplicada: rep.normaAplicada,
      observaciones: rep.observaciones,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _reportesMigracion.add(stamped);
    _logAudit(
      hoja: 'reporte_migracion',
      celda: 'A${_reportesMigracion.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.metrica}: ${stamped.valorEstado}',
      accion: 'alta_control_migracion',
      norma: stamped.normaAplicada,
      observaciones: stamped.observaciones,
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
    final stamped = ChecklistISO(
      nro: check.nro,
      control: check.control,
      norma: check.norma,
      estado: check.estado,
      evidencia: check.evidencia,
      timestamp: check.timestamp,
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
    _checklistIsos.add(stamped);
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'A${_checklistIsos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${stamped.control} (${stamped.norma})',
      accion: 'alta_requisito_iso',
      norma: stamped.norma,
      observaciones: stamped.evidencia,
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
        organizacionId: old.organizacionId,
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _ventas = [
      Venta(
        id: 'v00000001',
        fecha: DateTime(2026, 4, 3),
        clienteId: 'c00000001',
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        metodoPagoId: 'mp00000001',
        comisionPagoMovilBs: 0.0,
        montoBs: 9480.0,
        montoUsd: 20.0,
        abonoUsd: 20.0,
        deudaUsd: 0.0,
        totalPagarUsd: 20.0,
        validacion: 'OK',
        estado: EstadoVenta.pagada,
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _ventaItems = [
      const VentaItem(
        id: 'vi00000001',
        ventaId: 'v00000001',
        itemId: 'p00000001',
        cantidad: 1,
        precioUsd: 20.0,
        subtotalUsd: 20.0,
      ),
    ];

    _abonos = [
      Abono(
        id: 'ab00000001',
        ventaId: 'v00000001',
        fecha: DateTime(2026, 4, 3),
        monto: 20.0,
        metodoPagoId: 'mp00000001',
        tasaId: 't00000001',
      ),
    ];

    _tasas = [
      TasaRegistro(
        id: 't00000001',
        fecha: DateTime(2026, 4, 3),
        moneda: 'USD',
        valor: 474.0,
        fuente: 'bcv',
      ),
      TasaRegistro(
        id: 't00000002',
        fecha: DateTime(2026, 4, 2),
        moneda: 'USD',
        valor: 473.5,
        fuente: 'bcv',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _reportesMigracion = [
      const ReporteMigracion(
        metrica: 'Integridad Referencial (FKs)',
        valorEstado: '100% Conforme',
        normaAplicada: 'ISO 8000 §4.2',
        observaciones: '0 referencias huérfanas en clientes e inventario',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const ReporteMigracion(
        metrica: 'Cumplimiento Formatos Internacionales',
        valorEstado: 'E.164 y ISO 8601',
        normaAplicada: 'RFC 4180 / ISO 8601',
        observaciones: 'Fechas estandarizadas en YYYY-MM-DD y teléfonos con prefijo de país',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const ReporteMigracion(
        metrica: 'Seguridad y Cero Polling',
        valorEstado: 'Activo',
        normaAplicada: 'ISO/IEC 25010 / ISO 27001',
        observaciones: 'Actualizaciones bajo demanda manual sin temporizadores periódicos',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
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
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        nro: 2,
        control: 'Hash SHA-256 original registrado en bitácora',
        norma: 'NIST SP 800-53',
        estado: '☑',
        evidencia: 'audit_log!E2',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        nro: 3,
        control: '0 encabezados duplicados en 9 hojas',
        norma: 'ISO 8000 §4.1',
        estado: '☑',
        evidencia: 'Hojas: clientes, inventario, ventas, compras_divisas, etc.',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        nro: 4,
        control: 'Accesibilidad y Tap Targets mínimos 48x48',
        norma: 'WCAG 2.2 AA',
        estado: '☑',
        evidencia: 'AppButton, AppCard y controles interactivos',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _seguridad = [
      const Seguridad(
        biometrico: true,
        desbloqueoFacial: false,
        dosFactores: false,
        usuarioEmail: 'neidapulgar1989@gmail.com',
      ),
    ];

    _usuarios = [
      const Usuario(id: 'u00000001', email: 'neidapulgar1989@gmail.com', nombre: 'Neida'),
      const Usuario(id: 'u00000002', email: 'xhnl21@gmail.com', nombre: ''),
    ];

    _organizaciones = [
      const Organizacion(id: '67774411-6aa1-4aa3-a4b2-d3fc6913b768', nombre: 'Estilo Neutral'),
    ];

    _monedasOrganizacion = [
      MonedaOrganizacion(
        id: 'mo00000001',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
        moneda: 'USD',
        actualizadoEn: DateTime(2026, 4, 3),
      ),
    ];

    _usuarioOrganizaciones = [
      const UsuarioOrganizacion(
        usuarioEmail: 'neidapulgar1989@gmail.com',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const UsuarioOrganizacion(
        usuarioEmail: 'xhnl21@gmail.com',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _metodosPago = [
      const MetodoPago(id: 'mp00000001', nombre: 'Efectivo', status: true),
      const MetodoPago(id: 'mp00000002', nombre: 'Pago Movil', status: true),
      const MetodoPago(id: 'mp00000003', nombre: 'Transferencia', status: true),
      const MetodoPago(id: 'mp00000004', nombre: 'Zelle', status: true),
      const MetodoPago(id: 'mp00000005', nombre: 'Binance', status: true),
      const MetodoPago(id: 'mp00000006', nombre: 'Otro', status: true),
    ];
  }

  // ===========================================================================
  // CRUD 10: SEGURIDAD (hoja seguridad)
  // ===========================================================================

  /// Reemplaza (o inserta si no existía aún) la fila de seguridad del usuario
  /// activo dentro de la lista [_seguridad], que contiene una fila por usuario.
  void _replaceSeguridadForCurrentUsuario(Seguridad nuevo) {
    final index = _seguridad.indexWhere(
      (s) => _currentUsuarioEmail != null && s.usuarioEmail == _currentUsuarioEmail,
    );
    if (index != -1) {
      _seguridad[index] = nuevo;
    } else {
      _seguridad.add(nuevo);
    }
  }

  static const Map<String, String> _etiquetasMetodoSeguridad = {
    'biometrico': 'Biométrico',
    'desbloqueo_facial': 'Desbloqueo facial',
    'dos_factores': '2FA',
  };

  /// Selecciona el único método de seguridad activo para el usuario actual.
  /// Los tres métodos son mutuamente excluyentes: activar uno desactiva
  /// automáticamente los otros dos. Pasar `null` desactiva todos (login solo
  /// con Google, sin paso adicional). Es una preferencia por usuario, no por
  /// organización: así, un dispositivo incompatible de un usuario no afecta
  /// el método configurado por otros usuarios de la misma organización.
  void setMetodoSeguridad(String? metodo) {
    assert(
      metodo == null || _etiquetasMetodoSeguridad.containsKey(metodo),
      'Método de seguridad inválido: $metodo',
    );

    final old = seguridad;
    final nuevo = Seguridad(
      usuarioEmail: _currentUsuarioEmail ?? old.usuarioEmail,
      biometrico: metodo == 'biometrico',
      desbloqueoFacial: metodo == 'desbloqueo_facial',
      dosFactores: metodo == 'dos_factores',
    );
    _replaceSeguridadForCurrentUsuario(nuevo);

    final anterior = _etiquetasMetodoSeguridad[old.metodoActivo] ?? 'Ninguno';
    final actual = _etiquetasMetodoSeguridad[metodo] ?? 'Ninguno';
    _logAudit(
      hoja: 'seguridad',
      celda: 'A2:C2',
      valorAnterior: anterior,
      valorNuevo: actual,
      accion: 'cambio_metodo_seguridad',
      norma: 'ISO/IEC 27001 §9.4',
      observaciones: 'Método de seguridad activo cambiado de "$anterior" a "$actual"',
    );
    _postToAppsScript({
      'action': 'set_metodo_seguridad',
      'sheet': 'seguridad',
      'biometrico': nuevo.biometrico,
      'desbloqueo_facial': nuevo.desbloqueoFacial,
      'dos_factores': nuevo.dosFactores,
      'usuario_email': nuevo.usuarioEmail,
    });
    notifyListeners();
  }

  // ===========================================================================
  // CRUD 11: USUARIOS (hoja usuarios) + membresía (hoja usuario_organizacion)
  // ===========================================================================

  String get nextUsuarioId {
    final maxId = _usuarios.fold<int>(0, (prev, u) {
      final numStr = u.id.replaceAll(RegExp(r'[^0-9]'), '');
      final n = int.tryParse(numStr) ?? 0;
      return n > prev ? n : prev;
    });
    return 'u${(maxId + 1).toString().padLeft(8, '0')}';
  }

  UsuarioOrganizacion? _membresiaDe(String email) {
    final normalized = email.trim().toLowerCase();
    for (final rel in _usuarioOrganizaciones) {
      if (rel.usuarioEmail == normalized) return rel;
    }
    return null;
  }

  /// Registra un nuevo usuario autorizado y su membresía a [organizacionId].
  Future<bool> addUsuario(Usuario usuario, {required String organizacionId}) async {
    _usuarios.add(usuario);
    final membresia = UsuarioOrganizacion(usuarioEmail: usuario.email, organizacionId: organizacionId);
    _usuarioOrganizaciones.add(membresia);
    _logAudit(
      hoja: 'usuarios',
      celda: 'A${_usuarios.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${usuario.id} (${usuario.email})',
      accion: 'alta_usuario',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Alta de usuario autorizado, organización $organizacionId',
    );
    notifyListeners();

    final resultados = await Future.wait([
      _postToAppsScript({'action': 'create', 'sheet': 'usuarios', 'data': usuario.toMap()}),
      _postToAppsScript({'action': 'create', 'sheet': 'usuario_organizacion', 'data': membresia.toMap()}),
    ]);
    return resultados.every((ok) => ok);
  }

  /// Actualiza nombre y organización de un usuario existente. El email es
  /// inmutable una vez creado (es la clave usada por `seguridad` y por el
  /// login) para evitar dejar huérfanas otras filas que lo referencian.
  Future<bool> updateUsuario(Usuario usuario, {required String organizacionId}) async {
    final index = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (index == -1) return false;
    _usuarios[index] = usuario;

    final membresiaExistente = _membresiaDe(usuario.email);
    final membresia = UsuarioOrganizacion(usuarioEmail: usuario.email, organizacionId: organizacionId);
    final relIndex = _usuarioOrganizaciones.indexWhere((r) => r.usuarioEmail == usuario.email);
    if (relIndex != -1) {
      _usuarioOrganizaciones[relIndex] = membresia;
    } else {
      _usuarioOrganizaciones.add(membresia);
    }

    _logAudit(
      hoja: 'usuarios',
      celda: 'A${index + 2}',
      valorAnterior: usuario.id,
      valorNuevo: '${usuario.nombre} → org $organizacionId',
      accion: 'actualizacion_usuario',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Edición de usuario vía App Móvil',
    );
    notifyListeners();

    final resultados = await Future.wait([
      _postToAppsScript({
        'action': 'update',
        'sheet': 'usuarios',
        'id': usuario.id,
        'data': usuario.toMap(),
      }),
      _postToAppsScript({
        'action': membresiaExistente != null ? 'update' : 'create',
        'sheet': 'usuario_organizacion',
        'id': usuario.email,
        'data': membresia.toMap(),
      }),
    ]);
    return resultados.every((ok) => ok);
  }

  /// Elimina un usuario y su membresía a organización. No elimina su fila de
  /// `seguridad` (queda huérfana pero inofensiva: nadie puede volver a
  /// loguearse con ese email para usarla).
  Future<bool> deleteUsuario(Usuario usuario) async {
    _usuarios.removeWhere((u) => u.id == usuario.id);
    final teniaMembresia = _usuarioOrganizaciones.any((r) => r.usuarioEmail == usuario.email);
    _usuarioOrganizaciones.removeWhere((r) => r.usuarioEmail == usuario.email);

    _logAudit(
      hoja: 'usuarios',
      celda: 'A-',
      valorAnterior: '${usuario.id} (${usuario.email})',
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_usuario',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Baja de acceso de usuario vía App Móvil',
    );
    notifyListeners();

    final resultados = await Future.wait([
      _postToAppsScript({'action': 'delete', 'sheet': 'usuarios', 'id': usuario.id}),
      if (teniaMembresia)
        _postToAppsScript({'action': 'delete', 'sheet': 'usuario_organizacion', 'id': usuario.email}),
    ]);
    return resultados.every((ok) => ok);
  }

  // ===========================================================================
  // CRUD 12: ORGANIZACIONES (hoja organizaciones)
  // ===========================================================================

  String _generarOrganizacionId() {
    final random = Random.secure();
    List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variante RFC 4122
    String hex(int start, int end) =>
        bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Cantidad de usuarios que pertenecen a [organizacionId] (usado para
  /// bloquear el borrado de organizaciones con usuarios activos).
  int usuariosEnOrganizacion(String organizacionId) =>
      _usuarioOrganizaciones.where((r) => r.organizacionId == organizacionId).length;

  Future<bool> addOrganizacion(String nombre) async {
    final nuevo = Organizacion(id: _generarOrganizacionId(), nombre: nombre);
    _organizaciones.add(nuevo);
    _logAudit(
      hoja: 'organizaciones',
      celda: 'A${_organizaciones.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${nuevo.id} (${nuevo.nombre})',
      accion: 'alta_organizacion',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Alta de organización vía App Móvil',
    );
    notifyListeners();
    return _postToAppsScript({
      'action': 'create',
      'sheet': 'organizaciones',
      'data': nuevo.toMap(),
    });
  }

  Future<bool> updateOrganizacion(Organizacion organizacion) async {
    final index = _organizaciones.indexWhere((o) => o.id == organizacion.id);
    if (index == -1) return false;
    _organizaciones[index] = organizacion;
    _logAudit(
      hoja: 'organizaciones',
      celda: 'A${index + 2}',
      valorAnterior: organizacion.id,
      valorNuevo: organizacion.nombre,
      accion: 'actualizacion_organizacion',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Edición de organización vía App Móvil',
    );
    notifyListeners();
    return _postToAppsScript({
      'action': 'update',
      'sheet': 'organizaciones',
      'id': organizacion.id,
      'data': organizacion.toMap(),
    });
  }

  /// Elimina una organización. Se rechaza si todavía tiene usuarios
  /// asociados (ver [usuariosEnOrganizacion]), para no dejar membresías
  /// huérfanas apuntando a una organización inexistente.
  Future<bool> deleteOrganizacion(String organizacionId) async {
    if (usuariosEnOrganizacion(organizacionId) > 0) {
      Logger.warning(
        'SheetsDataService: Se intentó eliminar la organización $organizacionId con usuarios activos; operación rechazada.',
      );
      return false;
    }
    final removed = _organizaciones.where((o) => o.id == organizacionId).toList();
    _organizaciones.removeWhere((o) => o.id == organizacionId);
    _logAudit(
      hoja: 'organizaciones',
      celda: 'A-',
      valorAnterior: removed.isNotEmpty ? '${removed.first.id} (${removed.first.nombre})' : organizacionId,
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_organizacion',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Baja de organización vía App Móvil',
    );
    notifyListeners();
    return _postToAppsScript({
      'action': 'delete',
      'sheet': 'organizaciones',
      'id': organizacionId,
    });
  }

  // ===========================================================================
  // CRUD 12: MÉTODOS DE PAGO (hoja metodo pago)
  // ===========================================================================

  /// Resuelve el nombre a mostrar de un método de pago a partir de su ID
  /// (clave foránea guardada en `ventas.tipo_pago` / `abonos.metodo_pago`).
  /// Si el ID no existe (dato huérfano o pre-migración), se devuelve tal cual
  /// para no ocultar el valor original.
  String metodoPagoNombre(String metodoPagoId) {
    final metodo = _metodosPago.where((m) => m.id == metodoPagoId).firstOrNull;
    return metodo?.nombre ?? metodoPagoId;
  }

  /// Comprueba si un método de pago (por su ID) está siendo utilizado en
  /// alguna venta o registro de abono — la relación se verifica por clave
  /// foránea, no por nombre, para que un método renombrado siga detectándose
  /// correctamente como "en uso".
  bool isMetodoPagoEnUso(String metodoPagoId) {
    return _ventas.any((v) => v.metodoPagoId == metodoPagoId) ||
        _abonos.any((a) => a.metodoPagoId == metodoPagoId);
  }

  /// Agrega un nuevo método de pago a la hoja "metodo pago".
  Future<void> addMetodoPago({required String nombre}) async {
    final trimmed = nombre.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El nombre del método de pago no puede estar vacío');
    }

    if (_metodosPago.any((m) => m.nombre.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('Ya existe un método de pago con el nombre "$trimmed"');
    }

    int maxIdNum = 0;
    for (final m in _metodosPago) {
      final digits = RegExp(r'\d+').firstMatch(m.id)?.group(0);
      if (digits != null) {
        final val = int.tryParse(digits) ?? 0;
        if (val > maxIdNum) maxIdNum = val;
      }
    }
    final nextId = 'mp${(maxIdNum + 1).toString().padLeft(8, '0')}';

    final nuevo = MetodoPago(id: nextId, nombre: trimmed, status: true);
    _metodosPago.add(nuevo);

    _logAudit(
      hoja: 'metodo pago',
      celda: 'A${_metodosPago.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$nextId: $trimmed',
      accion: 'creacion_metodo_pago',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Creación de método de pago "$trimmed"',
    );

    _postToAppsScript({
      'action': 'create',
      'sheet': 'metodo pago',
      'data': nuevo.toMap(),
    });

    notifyListeners();
  }

  /// Alterna el status de un método de pago (activo/inactivo).
  /// Si se intenta desactivar un método en uso, se bloquea arrojando un error.
  Future<bool> toggleMetodoPagoStatus(String id) async {
    final idx = _metodosPago.indexWhere((m) => m.id == id);
    if (idx == -1) return false;

    final actual = _metodosPago[idx];
    final nuevoStatus = !actual.status;

    if (!nuevoStatus && isMetodoPagoEnUso(actual.id)) {
      throw StateError(
        'No se puede deshabilitar el método de pago "${actual.nombre}" porque ya fue utilizado en transacciones registradas.',
      );
    }

    _metodosPago[idx] = actual.copyWith(status: nuevoStatus);

    _logAudit(
      hoja: 'metodo pago',
      celda: 'C${idx + 2}',
      valorAnterior: actual.status.toString(),
      valorNuevo: nuevoStatus.toString(),
      accion: 'cambio_status_metodo_pago',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Método "${actual.nombre}" ${nuevoStatus ? "activado" : "deshabilitado"}',
    );

    _postToAppsScript({
      'action': 'update',
      'sheet': 'metodo pago',
      'id': id,
      'data': {'status': nuevoStatus},
    });

    notifyListeners();
    return true;
  }

  /// Elimina un método de pago si no está en uso.
  Future<bool> deleteMetodoPago(String id) async {
    final idx = _metodosPago.indexWhere((m) => m.id == id);
    if (idx == -1) return false;

    final actual = _metodosPago[idx];
    if (isMetodoPagoEnUso(actual.id)) {
      throw StateError(
        'No se puede eliminar el método de pago "${actual.nombre}" porque ya fue utilizado en transacciones registradas.',
      );
    }

    _metodosPago.removeAt(idx);

    _logAudit(
      hoja: 'metodo pago',
      celda: 'A${idx + 2}',
      valorAnterior: actual.nombre,
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_metodo_pago',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Eliminación del método de pago "${actual.nombre}"',
    );

    _postToAppsScript({
      'action': 'delete',
      'sheet': 'metodo pago',
      'id': id,
    });

    notifyListeners();
    return true;
  }

  // ===========================================================================
  // CRUD 13: TASAS (hoja tasas)
  // ===========================================================================

  /// Le pide al Apps Script que corra `obtenerTasaBCV()` ahora mismo (en vez
  /// de esperar al trigger diario) y refresca la hoja "tasas" local con el
  /// resultado. Devuelve `false` si no se pudo contactar el servidor o si
  /// `obtenerTasaBCV()` reportó un error (ej. dolarvzla.com no respondió).
  Future<bool> refrescarTasaHoy() async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) return false;

    try {
      var response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'refrescar_tasas', 'sheet': 'tasas'}),
      ).timeout(const Duration(seconds: 20));

      if ((response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307) &&
          response.headers.containsKey('location')) {
        final redirectUrl = response.headers['location']!;
        try {
          response = await _httpClient.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 20));
        } catch (_) {}
      }

      if (response.statusCode != 200) return false;

      final body = jsonDecode(response.body);
      if (body['status'] != 'success') {
        Logger.error('SheetsDataService: refrescarTasaHoy falló: ${body['message']}');
        return false;
      }

      await _fetchSheet(
        'tasas',
        _parseTasas,
        expectedHeaders: const ['id', 'fecha', 'moneda', 'valor', 'fuente', 'organizacion_id'],
      );
      _lastSync = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      Logger.error('SheetsDataService: excepción en refrescarTasaHoy', e);
      return false;
    }
  }

  String get nextTasaId {
    final maxId = _tasas.fold<int>(0, (prev, t) {
      final n = int.tryParse(t.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return n > prev ? n : prev;
    });
    return 't${(maxId + 1).toString().padLeft(8, '0')}';
  }

  /// Fija (o reemplaza) la tasa manual de [organizacionId]: si ya tenía una,
  /// se actualiza esa misma fila (misma FK, no se duplica); si no, se crea
  /// una nueva fila en "tasas" con fuente='manual'.
  Future<bool> setTasaManualOrganizacion(String organizacionId, String moneda, double valor) async {
    final existente = tasaManualOrganizacion(organizacionId);
    if (existente != null) {
      final index = _tasas.indexWhere((t) => t.id == existente.id);
      final actualizada = TasaRegistro(
        id: existente.id,
        fecha: DateTime.now(),
        moneda: moneda,
        valor: valor,
        fuente: 'manual',
        organizacionId: organizacionId,
      );
      _tasas[index] = actualizada;
      notifyListeners();
      return _postToAppsScript({
        'action': 'update',
        'sheet': 'tasas',
        'id': actualizada.id,
        'data': actualizada.toMap(),
      });
    }

    final nueva = TasaRegistro(
      id: nextTasaId,
      fecha: DateTime.now(),
      moneda: moneda,
      valor: valor,
      fuente: 'manual',
      organizacionId: organizacionId,
    );
    _tasas.insert(0, nueva);
    notifyListeners();
    return _postToAppsScript({
      'action': 'create',
      'sheet': 'tasas',
      'data': nueva.toMap(),
    });
  }

  /// Quita la tasa manual de [organizacionId] (si tenía una configurada).
  Future<bool> quitarTasaManualOrganizacion(String organizacionId) async {
    final existente = tasaManualOrganizacion(organizacionId);
    if (existente == null) return true;
    _tasas.removeWhere((t) => t.id == existente.id);
    notifyListeners();
    return _postToAppsScript({
      'action': 'delete',
      'sheet': 'tasas',
      'id': existente.id,
    });
  }

  // ===========================================================================
  // CRUD 14: MONEDA POR ORGANIZACIÓN (hoja moneda_organizacion)
  // ===========================================================================

  String get _nextMonedaOrganizacionId {
    final maxId = _monedasOrganizacion.fold<int>(0, (prev, m) {
      final n = int.tryParse(m.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return n > prev ? n : prev;
    });
    return 'mo${(maxId + 1).toString().padLeft(8, '0')}';
  }

  /// Fija (o reemplaza) la moneda base de [organizacionId]: si ya tenía una
  /// seleccionada, se actualiza esa misma fila (misma FK, no se duplica).
  Future<bool> setMonedaOrganizacion(String organizacionId, String moneda) async {
    final existenteIdx = _monedasOrganizacion.indexWhere((m) => m.organizacionId == organizacionId);

    if (existenteIdx != -1) {
      final actualizada = MonedaOrganizacion(
        id: _monedasOrganizacion[existenteIdx].id,
        organizacionId: organizacionId,
        moneda: moneda,
        actualizadoEn: DateTime.now(),
      );
      _monedasOrganizacion[existenteIdx] = actualizada;
      notifyListeners();
      return _postToAppsScript({
        'action': 'update',
        'sheet': 'moneda_organizacion',
        'id': actualizada.id,
        'data': actualizada.toMap(),
      });
    }

    final nueva = MonedaOrganizacion(
      id: _nextMonedaOrganizacionId,
      organizacionId: organizacionId,
      moneda: moneda,
      actualizadoEn: DateTime.now(),
    );
    _monedasOrganizacion.insert(0, nueva);
    notifyListeners();
    return _postToAppsScript({
      'action': 'create',
      'sheet': 'moneda_organizacion',
      'data': nueva.toMap(),
    });
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
