import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/logger.dart';
import '../../features/credits/domain/entities/client_credit.dart';
import '../../features/credits/domain/entities/credit_status.dart';
import '../../features/credits/domain/value_objects/credit_amount.dart';
import '../../features/credits/domain/value_objects/credit_id.dart';
import '../../features/credits/infrastructure/models/client_credit_model.dart';
import '../../features/notificaciones/domain/correo_clientes.dart';
import '../../features/notificaciones/domain/destino_notificacion.dart';
import '../../models/models.dart';
import '../storage/secure_token_storage.dart';
import 'batch/sheets_batch_executor.dart';
import 'sheets_config.dart';

/// Servicio centralizado de datos y sincronización para las 10 hojas de Google Sheets.
/// Arquitectura: Cero Polling, actualización bajo demanda, estado reactivo con CRUD completo
/// y trazabilidad de auditoría ISO 27001 / ISO 8000.
class SheetsDataService extends ChangeNotifier {
  final String spreadsheetId;
  String? _appsScriptUrl;
  String? get appsScriptUrl => _appsScriptUrl;
  final DioClient _dioClient;
  Dio get _dio => _dioClient.dio;

  SheetsDataService({
    String? spreadsheetId,
    String? appsScriptUrl,
    Dio? dio,
    this.datosDeRespaldo = true,
  })  : _accesoLeido = datosDeRespaldo,
        spreadsheetId = SheetsConfig.extractSpreadsheetId(spreadsheetId ?? SheetsConfig.defaultSpreadsheetId),
        _appsScriptUrl = appsScriptUrl ?? SheetsConfig.defaultAppsScriptUrl,
        _dioClient = DioClient(customDio: dio) {
    // No se pasa `baseOptions` a DioClient: hacerlo reemplazaría por completo
    // sus valores por defecto (connectTimeout, headers, etc.) en vez de
    // combinarse con ellos. Solo se ajusta `validateStatus` después de
    // construido, para que Apps Script pueda devolver 3xx/4xx sin que dio
    // los trate como excepción (los seguimos/leemos nosotros a mano).
    _dioClient.dio.options.validateStatus = (status) => status != null && status < 500;
  }

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
    const MetodoPago(id: 'mp00000009', nombre: 'Saldo a Favor', status: true),
  ];
  List<TasaRegistro> _tasas = [];
  List<MonedaOrganizacion> _monedasOrganizacion = [];
  List<ConfigNotificaciones> _configNotificaciones = [];
  List<TipoNotificacion> _tiposNotificacion = [];
  List<PlantillaNotificacion> _plantillasNotificacion = [];
  List<Banco> _bancos = [];
  List<CuentaBancaria> _cuentasBancarias = [];
  List<GaleriaItem> _galeria = [];
  List<ClientCredit> _creditosClientes = [];
  List<CodigoTelefono> _codigosTelefono = [
    const CodigoTelefono(id: 'ct00000001', codigo: '0414', status: true),
    const CodigoTelefono(id: 'ct00000002', codigo: '0424', status: true),
    const CodigoTelefono(id: 'ct00000003', codigo: '0416', status: true),
    const CodigoTelefono(id: 'ct00000004', codigo: '0426', status: true),
    const CodigoTelefono(id: 'ct00000005', codigo: '0412', status: true),
    const CodigoTelefono(id: 'ct00000006', codigo: '0422', status: true),
  ];
  List<CodigoTelefono> get codigosTelefono => List.unmodifiable(_codigosTelefono);
  List<String> get codigosTelefonoActivos {
    final list = _codigosTelefono.where((c) => c.status).map((c) => c.codigo).toList();
    return list.isNotEmpty ? list : const ['0414', '0424', '0416', '0426', '0412', '0422'];
  }

  List<TipoDocumento> _tiposDocumento = [
    const TipoDocumento(id: 'td00000001', tipo: 'V', descripcion: 'Venezolano', status: true),
    const TipoDocumento(id: 'td00000002', tipo: 'E', descripcion: 'Extranjero', status: true),
    const TipoDocumento(id: 'td00000003', tipo: 'J', descripcion: 'Jurídico', status: true),
    const TipoDocumento(id: 'td00000004', tipo: 'G', descripcion: 'Gubernamental', status: true),
  ];
  List<TipoDocumento> get tiposDocumento => List.unmodifiable(_tiposDocumento);
  List<String> get tiposDocumentoActivos {
    final list = _tiposDocumento.where((t) => t.status).map((t) => t.tipo).toList();
    return list.isNotEmpty ? list : const ['V', 'E', 'J', 'G'];
  }

  /// Historial de saldos a favor y compensaciones de créditos de clientes (hoja "creditos_clientes")
  List<ClientCredit> get creditosClientes =>
      List.unmodifiable(_creditosClientes.where((c) => _matchesCurrentOrg(c.organizacionId)));

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
    _accesoRevocadoEnServidor = null;
    notifyListeners();
  }

  String? _accesoRevocadoEnServidor;

  /// Con `true` (tests), al iniciar se cargan datos de ejemplo
  /// ([_seedFallbackData]) que quedan si la lectura falla. En la app es
  /// `false`: si no se puede leer la hoja, no se muestran datos inventados
  /// como si fueran reales (ni se autoriza el login con usuarios de ejemplo).
  final bool datosDeRespaldo;

  /// Se leyeron alguna vez las hojas de acceso (o hay datos de respaldo):
  /// distingue "la cuenta no está autorizada" de "no se pudo verificar".
  bool _accesoLeido;
  bool get accesoCargado => _accesoLeido;

  /// Motivo del último rechazo del servidor al leer (p. ej. "Sesión de
  /// Google emitida para otra aplicación"), o `null`.
  String? _ultimoErrorLectura;
  String? get ultimoErrorLectura => _ultimoErrorLectura;

  /// `true` si la última lectura falló porque el servidor rechazó el token de
  /// Google aun después de pedir uno nuevo: hay que volver a iniciar sesión.
  bool _sesionRechazadaEnLectura = false;
  bool get sesionRechazadaEnLectura => _sesionRechazadaEnLectura;

  /// Token de acceso de la sesión de Google ([SheetsAuth.tokenDeAcceso]). Va
  /// en cada pedido al Apps Script, que lo verifica con Google: así el
  /// servidor sabe quién es el usuario sin creerle el email a la app. Sin
  /// proveedor (tests, sin sesión) los pedidos van sin token.
  Future<String?> Function()? proveedorToken;

  /// Pide a Google un token nuevo descartando el guardado
  /// ([SheetsAuth.renovarTokenDeAcceso]). Se llama una vez cuando el servidor
  /// rechaza el token (`code: "no_autenticado"`).
  Future<String?> Function()? renovadorToken;

  /// Motivo con el que Apps Script rechazó una escritura porque el usuario de
  /// la sesión perdió el acceso (`code: "acceso_revocado"`), o `null`.
  /// `ControlAccesoSesion` lo escucha para cerrar la sesión.
  String? get accesoRevocadoEnServidor => _accesoRevocadoEnServidor;

  /// Vuelve a leer solo las hojas que deciden el acceso (`usuarios`,
  /// `organizaciones`, `usuario_organizacion`) y avisa a los listeners. Una
  /// lectura puntual por evento (p. ej. la app vuelve a primer plano), nunca
  /// periódica (docs/no_polling_policy.md). Sin red no cambia nada.
  Future<void> releerAcceso() async {
    if (_isLoading) return;
    try {
      await Future.wait([
        _fetchSheet('usuarios', _parseUsuarios, expectedHeaders: const ['id', 'email', 'nombre']),
        _fetchSheet('organizaciones', _parseOrganizaciones, expectedHeaders: const ['id', 'nombre']),
        _fetchSheet('usuario_organizacion', _parseUsuarioOrganizaciones,
            expectedHeaders: const ['id', 'usuario_email', 'organizacion_id']),
      ]);
      notifyListeners();
    } catch (e) {
      Logger.warning('SheetsDataService: no se pudo releer el acceso: $e');
    }
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
  /// Decide si [email] puede entrar a la app: tiene que estar en la hoja
  /// `usuarios` y tener membresía (`usuario_organizacion`) en una
  /// organización existente. Es el único control de acceso: "Autorizar
  /// acceso" y "Quitar acceso" en Usuarios lo modifican.
  ({String? organizacionId, String? motivo}) resolverAcceso(String email) {
    final normalized = email.trim().toLowerCase();
    if (!_usuarios.any((u) => u.email.trim().toLowerCase() == normalized)) {
      return (organizacionId: null, motivo: 'La cuenta $normalized no está registrada como usuario del sistema.');
    }
    if (_usuarios.any((u) => u.email.trim().toLowerCase() == normalized && !u.activo)) {
      return (organizacionId: null, motivo: 'La cuenta $normalized está inactiva.');
    }
    final organizacionId = organizacionIdForUsuario(normalized);
    if (organizacionId == null || organizacionId.trim().isEmpty) {
      return (organizacionId: null, motivo: 'La cuenta $normalized no pertenece a ninguna organización.');
    }
    if (!_organizaciones.any((o) => o.id == organizacionId)) {
      return (organizacionId: null, motivo: 'La organización asignada a $normalized ya no existe.');
    }
    return (organizacionId: organizacionId, motivo: null);
  }

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

  /// Clientes activos de la organización actual: los únicos a los que se les
  /// puede registrar una venta nueva.
  List<Cliente> get clientesActivos => List.unmodifiable(clientes.where((c) => c.activo));
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

  /// Catálogo de bancos (todos, también los inactivos, para mostrar el banco
  /// de una cuenta vieja).
  List<Banco> get bancos => List.unmodifiable(_bancos);

  Banco? bancoPorId(String id) => _bancos.where((b) => b.id == id).firstOrNull;

  /// Datos bancarios (transferencia y pago móvil) de la organización actual.
  List<CuentaBancaria> get cuentasBancarias =>
      List.unmodifiable(_cuentasBancarias.where((c) => _matchesCurrentOrg(c.organizacionId)));

  /// Catálogo de tipos de notificación (todos, también los inactivos, para
  /// poder mostrar el tipo de una plantilla vieja).
  List<TipoNotificacion> get tiposNotificacion => List.unmodifiable(_tiposNotificacion);

  /// Notificaciones guardadas para reutilizar de la organización actual.
  List<PlantillaNotificacion> get plantillasNotificacion =>
      List.unmodifiable(_plantillasNotificacion.where((p) => _matchesCurrentOrg(p.organizacionId)));

  PlantillaNotificacion? plantillaNotificacion(String id) =>
      plantillasNotificacion.where((p) => p.id == id).firstOrNull;

  /// Límites de envío de notificaciones de [organizacionId] (hoja
  /// "config_notificaciones"), o los de por defecto si no tiene fila.
  ConfigNotificaciones configNotificacionesDe(String organizacionId) =>
      _configNotificaciones.where((c) => c.organizacionId == organizacionId).firstOrNull ??
      ConfigNotificaciones.porDefecto(organizacionId);

  /// Catálogo de fotos subidas (hoja "galeria") — ver [fotoUrlPorId].
  List<GaleriaItem> get galeria => List.unmodifiable(_galeria);

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
  /// Con [cargarSinSesion] en `false` (la app), si todavía no hay sesión de
  /// Google no se lee nada: la hoja es privada y solo se lee por el Apps
  /// Script con la sesión. La primera carga la dispara el login
  /// ([esperarCargaInicial]).
  Future<void> initialize({bool cargarSinSesion = true}) async {
    try {
      final savedUrl = await SecureTokenStorage().getAppsScriptUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _appsScriptUrl = savedUrl;
      }
    } catch (_) {}
    if (datosDeRespaldo) _seedFallbackData();
    if (!cargarSinSesion && await _tokenDeAcceso() == null) return;
    await fetchAllSheets();
  }

  /// Carga en curso, para que [esperarCargaInicial] pueda esperarla.
  Future<void>? _fetchEnCurso;

  /// Espera a que haya terminado al menos una carga desde Google Sheets
  /// (la de [initialize] se lanza sin `await`). Si esa carga falla, quedan
  /// los datos de respaldo de [_seedFallbackData].
  Future<void> esperarCargaInicial() async {
    if (_lastSync != null) return;
    await (_fetchEnCurso ?? fetchAllSheets());
  }

  /// Carga bajo demanda de las 10 hojas desde Google Sheets mediante el endpoint GViz
  Future<void> fetchAllSheets({bool silent = false}) {
    final enCurso = _fetchEnCurso;
    if (enCurso != null) return enCurso;
    final carga = _fetchAllSheets(silent: silent);
    _fetchEnCurso = carga;
    return carga.whenComplete(() => _fetchEnCurso = null);
  }

  Future<void> _fetchAllSheets({bool silent = false}) async {
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
        safeFetch('clientes', _parseClientes, expectedHeaders: const [
          'id', 'nombre', 'telefono', 'email', 'saldo_deuda_usd', 'fecha_registro', 'organizacion_id',
        ]),
        safeFetch('inventario', _parseProductos, expectedHeaders: const [
          'id', 'cantidad', 'nombre', 'marca', 'modelo', 'talla', 'precio_usd',
        ]),
        // Catálogo de fotos — inventario.foto_id apunta acá por FK, nunca
        // guarda la URL directa (ver GaleriaItem/fotoUrlPorId).
        safeFetch(
          'galeria',
          _parseGaleria,
          expectedHeaders: const ['id', 'url', 'drive_file_id', 'nombre_archivo', 'fecha_subida'],
        ),
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
          expectedHeaders: const ['id', 'venta_id', 'fecha', 'monto', 'metodo_pago', 'tasa_id'],
        ),
        safeFetch('compras_divisas', _parseCompras, expectedHeaders: const [
          'id', 'fecha_compra', 'fecha_entrega', 'capital_usd', 'comision_binance_usd', 'numero_orden',
        ]),
        safeFetch('resumen_diario', _parseResumenes, expectedHeaders: const [
          'id', 'fecha', 'nro_ventas', 'total_bs', 'total_usd', 'tasa_bcv', 'tasa_usd',
          'usd_comprados', 'usd_vendidos', 'organizacion_id',
        ]),
        safeFetch('cuarentena', _parseCuarentenas, expectedHeaders: const [
          'id', 'id_registro_original', 'hoja_origen', 'fecha_deteccion', 'motivo_cuarentena',
          'datos_originales_json', 'estado', 'resolucion', 'hash_evidencia', 'organizacion_id',
        ]),
        safeFetch('audit_log', _parseAuditLogs, expectedHeaders: const [
          'id', 'timestamp_iso8601', 'usuario', 'hoja', 'celda', 'valor_anterior', 'valor_nuevo',
          'accion', 'norma_aplicada', 'observaciones',
        ]),
        safeFetch('reporte_migracion', _parseReportes, expectedHeaders: const [
          'id', 'metrica', 'valor_estado', 'norma_aplicada', 'observaciones', 'organizacion_id',
        ]),
        safeFetch('checklist_iso', _parseChecklists, expectedHeaders: const [
          'id', 'nro', 'control', 'norma', 'estado', 'evidencia', 'timestamp', 'organizacion_id',
        ]),
        // Estos 4 tienen esquema nuevo (ver docs/google/multi-organizacion.md):
        // se valida el encabezado para no aceptar filas de otra hoja si el
        // Sheet real todavía no fue migrado.
        safeFetch('seguridad', _parseSeguridad, expectedHeaders: const [
          'id', 'biometrico', 'desbloqueo_facial', 'dos_factores', 'usuario_email',
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
          expectedHeaders: const ['id', 'usuario_email', 'organizacion_id'],
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
        // Datos bancarios por organización y catálogo de bancos.
        safeFetch('bancos', _parseBancos, expectedHeaders: const ['id', 'codigo', 'nombre', 'status']),
        safeFetch('cuentas_bancarias', _parseCuentasBancarias,
            expectedHeaders: const ['id', 'organizacion_id', 'tipo', 'banco_id', 'titular']),
        // Notificaciones guardadas para reutilizar y su catálogo de tipos.
        safeFetch('tipos_notificacion', _parseTiposNotificacion, expectedHeaders: const ['id', 'nombre', 'status']),
        safeFetch('plantillas_notificacion', _parsePlantillasNotificacion,
            expectedHeaders: const ['id', 'organizacion_id', 'tipo_id', 'titulo', 'cuerpo']),
        // Límites de envío de notificaciones, una fila por organización.
        safeFetch(
          'config_notificaciones',
          _parseConfigNotificaciones,
          expectedHeaders: const ['id', 'organizacion_id', 'periodo', 'limite_por_usuario', 'limite_organizacion'],
        ),
        safeFetch(
          'moneda_organizacion',
          _parseMonedasOrganizacion,
          expectedHeaders: const ['id', 'organizacion_id', 'moneda', 'actualizado_en'],
        ),
        safeFetch(
          'codigo de telefonos',
          _parseCodigosTelefono,
          expectedHeaders: const ['id', 'codigo', 'status'],
        ),
        safeFetch(
          'tipo de documento',
          _parseTiposDocumento,
          expectedHeaders: const ['id', 'tipo', 'descripcion', 'status'],
        ),
        safeFetch(
          'creditos_clientes',
          _parseCreditosClientes,
          expectedHeaders: const [
            'id',
            'cliente_id',
            'fecha',
            'monto_usd',
            'origen_venta_id',
            'estado',
            'organizacion_id',
            'aplicado_a_venta_id',
            'fecha_aplicacion',
            'saldo_usd',
            'usuario_email',
            'hash_evidencia',
          ],
        ),
      ]);

      _reconciliarVentasConAbonos();

      if (successCount > 0) {
        _lastSync = DateTime.now();
        _errorMessage = null;
      } else {
        final isPrivateDoc = errors.any((e) => e.contains('401') || e.contains('Privado'));
        final motivoServidor = _ultimoErrorLectura;
        if (motivoServidor != null) {
          // La hoja es privada a propósito: se lee por el Apps Script, que
          // rechazó la lectura (sesión, app no permitida, acceso).
          _errorMessage = 'No se pudieron cargar los datos: $motivoServidor';
          Logger.warning('SheetsDataService: el servidor rechazó la lectura: $motivoServidor');
        } else if (isPrivateDoc) {
          // Normal sin sesión de Google: la hoja es privada y solo se lee por
          // el Apps Script con la sesión iniciada.
          _errorMessage = 'No se pudieron cargar los datos. Iniciá sesión de nuevo.';
          Logger.info('SheetsDataService: la hoja es privada; se lee por el Apps Script con la sesión.');
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

  Future<String?> _tokenDeAcceso() async {
    final proveedor = proveedorToken;
    if (proveedor == null) return null;
    try {
      return await proveedor();
    } catch (_) {
      return null;
    }
  }

  /// Lectura en curso por el Apps Script: las hojas que se piden en el mismo
  /// momento (p. ej. las ~30 de la carga inicial) viajan en un solo pedido.
  _LoteLectura? _loteLectura;

  /// Filas de [hoja] leídas por el Apps Script (`leer_hojas`, con la sesión de
  /// Google verificada), o `null` si no se pudo (sin sesión, sin conexión,
  /// script viejo): entonces se lee por gviz, que solo funciona mientras la
  /// hoja esté compartida por enlace.
  Future<List<List<String>>?> _filasDelServidor(String hoja) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty || proveedorToken == null) return null;
    final lote = _loteLectura ??= _LoteLectura();
    lote.hojas.add(hoja);
    if (!lote.programado) {
      lote.programado = true;
      // Después de que se encolen todas las lecturas pedidas a la vez.
      Future(() => _enviarLoteLectura(lote));
    }
    final hojas = await lote.resultado.future;
    if (hojas == null) return null;
    return hojas[hoja] ?? const []; // la hoja no existe: sin datos
  }

  Future<void> _enviarLoteLectura(_LoteLectura lote) async {
    if (identical(_loteLectura, lote)) _loteLectura = null;
    Map<String, List<List<String>>>? hojas;
    _sesionRechazadaEnLectura = false;
    try {
      if (await _tokenDeAcceso() != null) {
        final r = await _postAppsScriptJson({'action': 'leer_hojas', 'hojas': lote.hojas.toList()});
        final data = r.data;
        _ultimoErrorLectura = data == null
            ? 'El servidor no respondió.'
            : (data['status'] == 'success' ? null : data['message']?.toString());
        _sesionRechazadaEnLectura = data?['code'] == 'no_autenticado';
        if (data != null && data['status'] == 'success' && data['hojas'] is Map) {
          Logger.info('SheetsDataService: leer_hojas (${lote.hojas.length} hojas) '
              'vía ${data['via'] ?? '?'} en ${data['ms'] ?? '?'} ms del servidor');
          hojas = {
            for (final e in (data['hojas'] as Map).entries)
              '${e.key}': [
                for (final fila in (e.value as List)) [for (final celda in (fila as List)) '${celda ?? ''}'],
              ],
          };
        }
      }
    } catch (e) {
      Logger.warning('SheetsDataService: no se pudieron leer las hojas por el Apps Script: $e');
    }
    lote.resultado.complete(hojas);
  }

  Future<void> _fetchSheet(
    String sheetName,
    void Function(List<List<String>>) parser, {
    List<String>? expectedHeaders,
  }) async {
    final rows = await _filasDelServidor(sheetName) ?? await _filasPorGviz(sheetName);
    if (rows == null || rows.isEmpty) return;
    _procesarFilas(sheetName, rows, parser, expectedHeaders: expectedHeaders);
  }

  /// Lectura pública por gviz (CSV). `null` si vino vacía; lanza si falló.
  Future<List<List<String>>?> _filasPorGviz(String sheetName) async {
    final cleanId = SheetsConfig.extractSpreadsheetId(spreadsheetId);
    final url = Uri.parse(
      // headers=1: la fila 1 es el encabezado. Sin esto gviz lo adivina y, en
      // hojas solo de texto (p. ej. audit_log), fusiona filas de datos con él.
      'https://docs.google.com/spreadsheets/d/$cleanId/gviz/tq?tqx=out:csv&headers=1&sheet=$sheetName',
    );
    final response = await _dio.get<String>(
      url.toString(),
      options: Options(
        headers: {'User-Agent': 'Flutter-EstiloNeutral/1.0'},
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final body = response.data ?? '';

    if (response.statusCode == 200 && body.isNotEmpty) {
      if (body.contains('<html') || body.contains('ServiceLogin')) {
        throw Exception('HTTP 401: Documento Privado');
      }
      return parseCsv(body);
    } else if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
    }
    return null;
  }

  /// Valida el encabezado de [rows] (fila 1) y pasa los datos a [parser].
  void _procesarFilas(
    String sheetName,
    List<List<String>> rows,
    void Function(List<List<String>>) parser, {
    List<String>? expectedHeaders,
  }) {
    // Si se pasan encabezados esperados, se valida la fila 1 antes de parsear.
    // El endpoint GViz puede devolver silenciosamente los datos de OTRA hoja
    // (por ejemplo, si `sheetName` todavía no existe en el Sheet real) — sin
    // esto, esas filas ajenas se interpretarían como datos válidos de
    // `sheetName`, mezclando columnas de una hoja con las de otra.
    if (expectedHeaders != null) {
      final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
      bool empiezaCon(List<String> esperado) =>
          header.length >= esperado.length &&
          List.generate(esperado.length, (i) => header[i] == esperado[i].toLowerCase()).every((ok) => ok);
      // También se acepta el formato anterior a la columna `id` (hoja que
      // todavía no se migró): los modelos leen ambos (ver FilaHoja).
      final matches = empiezaCon(expectedHeaders) ||
          (expectedHeaders.first == 'id' && empiezaCon(expectedHeaders.sublist(1)));
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

  void _parseGaleria(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => GaleriaItem.fromRow(r))
        .toList();
    final localPending = _galeria.where((local) => !cloud.any((g) => g.id == local.id)).toList();
    _galeria = [...cloud, ...localPending];
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

  /// Reconcilia el abono acumulado y la deuda pendiente de cada factura
  /// contra el libro mayor de abonos (_abonos), garantizando consistencia
  /// matemática incluso si la hoja "ventas" en Google Sheets no calculó
  /// el SUMIF o tiene valor estático desfasado.
  void _reconciliarVentasConAbonos() {
    for (var i = 0; i < _ventas.length; i++) {
      final v = _ventas[i];
      final abonosDeEstaVenta = _abonos.where((a) => a.ventaId == v.id).toList();
      if (abonosDeEstaVenta.isNotEmpty) {
        final totalAbonado = abonosDeEstaVenta.fold<double>(0.0, (sum, a) => sum + a.monto);
        if (totalAbonado != v.abonoUsd) {
          final deudaRecalculada = (v.totalPagarUsd - totalAbonado).clamp(0.0, double.infinity);
          final estadoRecalculado = deudaRecalculada <= 0 ? EstadoVenta.pagada : EstadoVenta.pendiente;
          _ventas[i] = Venta(
            id: v.id,
            fecha: v.fecha,
            clienteId: v.clienteId,
            tasaBcv: v.tasaBcv,
            tasaUsd: v.tasaUsd,
            metodoPagoId: v.metodoPagoId,
            comisionPagoMovilBs: v.comisionPagoMovilBs,
            montoBs: v.montoBs,
            montoUsd: v.montoUsd,
            abonoUsd: totalAbonado,
            deudaUsd: deudaRecalculada,
            totalPagarUsd: v.totalPagarUsd,
            validacion: v.validacion,
            estado: estadoRecalculado,
            organizacionId: v.organizacionId,
          );
        }
      }
    }
  }

  void _parseCompras(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = _filasLegibles(
      'compras_divisas',
      rows.where((r) => r.isNotEmpty && r.first.isNotEmpty),
      CompraDivisa.fromRow,
    );
    final localPending = _comprasDivisas.where((local) => !cloud.any((c) => c.id == local.id)).toList();
    _comprasDivisas = [...cloud, ...localPending];
  }

  void _parseResumenes(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _resumenesDiarios = _filasLegibles(
      'resumen_diario',
      rows.where((r) => r.any((c) => c.trim().isNotEmpty)),
      ResumenDiario.fromRow,
    );
  }

  /// Convierte las filas con [leer] y descarta (con advertencia en el log)
  /// las que tienen una fecha ilegible, en vez de leerlas como "hoy".
  List<T> _filasLegibles<T>(String hoja, Iterable<List<String>> filas, T Function(List<String>) leer) {
    final resultado = <T>[];
    for (final fila in filas) {
      try {
        resultado.add(leer(fila));
      } on FormatException catch (e) {
        Logger.warning('SheetsDataService: fila de $hoja descartada (${e.message}: "${e.source}"): $fila');
      }
    }
    return resultado;
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
    _accesoLeido = true;
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

  void _parseBancos(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _bancos = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => Banco.fromRow(r))
        .where((b) => b.id.isNotEmpty && b.nombre.isNotEmpty)
        .toList();
  }

  void _parseCuentasBancarias(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _cuentasBancarias = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => CuentaBancaria.fromRow(r))
        .whereType<CuentaBancaria>()
        .toList();
  }

  void _parseTiposNotificacion(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _tiposNotificacion = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => TipoNotificacion.fromRow(r))
        .where((t) => t.id.isNotEmpty && t.nombre.isNotEmpty)
        .toList();
  }

  void _parsePlantillasNotificacion(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _plantillasNotificacion = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => PlantillaNotificacion.fromRow(r))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }

  void _parseConfigNotificaciones(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _configNotificaciones = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => ConfigNotificaciones.fromRow(r))
        .where((c) => c.id.isNotEmpty && c.organizacionId.isNotEmpty)
        .toList();
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

  void _parseCreditosClientes(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final cloud = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => ClientCreditModel.fromRow(r))
        .toList();
    final localPending = _creditosClientes.where((local) => !cloud.any((c) => c.id == local.id)).toList();
    _creditosClientes = [...cloud, ...localPending];
  }

  void _parseCodigosTelefono(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _codigosTelefono = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => CodigoTelefono.fromRow(r))
        .toList();
  }

  void _parseTiposDocumento(List<List<String>> rows) {
    if (rows.isEmpty) return;
    _tiposDocumento = rows
        .where((r) => r.isNotEmpty && r.first.trim().isNotEmpty)
        .map((r) => TipoDocumento.fromRow(r))
        .toList();
  }

  void addCreditoClienteLocal(ClientCredit credit) {
    _creditosClientes.removeWhere((c) => c.id == credit.id);
    _creditosClientes.insert(0, credit);
    notifyListeners();
  }

  void updateCreditoClienteLocal(ClientCredit credit) {
    final idx = _creditosClientes.indexWhere((c) => c.id == credit.id);
    if (idx != -1) {
      _creditosClientes[idx] = credit;
    } else {
      _creditosClientes.add(credit);
    }
    notifyListeners();
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
      // Sin usuario identificado queda vacío: no se inventa un autor (R7).
      usuario: _currentUsuarioEmail ?? '',
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

  /// Hace un POST a Apps Script con [payload] y sigue el redirect de eco de
  /// Google (`script.googleusercontent.com/macros/echo?...`) si aparece —
  /// dio no lo sigue automáticamente en un POST, así que hay que pedirlo a
  /// mano con un GET aparte. Ese eco a veces responde con un código
  /// distinto de 200 de forma transitoria aunque Apps Script ya haya
  /// terminado de procesar la acción; se reintenta con backoff antes de
  /// darse por vencido. `huboRedirect` indica si Apps Script llegó a
  /// aceptar el POST (recibimos un 302) aunque no se haya podido confirmar
  /// el contenido de la respuesta — lo usa `_postToAppsScript` para no
  /// reportar un fallo falso en acciones donde no hace falta leer el body.
  Future<({bool huboRedirect, Map<String, dynamic>? data})> _postAppsScriptJson(
    Map<String, dynamic> payload, {
    Duration sendTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 60),
    List<Duration> reintentosEco = const [
      Duration(milliseconds: 500),
      Duration(milliseconds: 1000),
      Duration(milliseconds: 2000),
    ],
    bool tokenRenovado = false,
  }) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) return (huboRedirect: false, data: null);

    // El script rechaza la escritura si esta cuenta perdió el acceso
    // (`code: "acceso_revocado"`, ver ControlAccesoSesion).
    final usuario = _currentUsuarioEmail;
    final token = await _tokenDeAcceso();
    final cuerpo = {
      ...payload,
      if (usuario != null) 'usuario_sesion': usuario,
      // "access_token": el Logger lo oculta en los registros.
      if (token != null) 'access_token': token,
    };

    Response response;
    try {
      response = await _dio.post(
        url,
        data: cuerpo,
        options: Options(sendTimeout: sendTimeout, receiveTimeout: receiveTimeout),
      );
    } catch (e) {
      Logger.error('SheetsDataService: excepción en POST a Apps Script', e);
      return (huboRedirect: false, data: null);
    }

    var huboRedirect = false;
    final location = response.headers.value('location');
    if ((response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307) &&
        location != null) {
      huboRedirect = true;
      Logger.api('Siguiendo redirección de Apps Script: $location', isRequest: true);
      for (var intento = 0; intento < reintentosEco.length; intento++) {
        try {
          response = await _dio.get(location, options: Options(receiveTimeout: receiveTimeout));
        } catch (e) {
          Logger.warning('SheetsDataService: eco de Apps Script falló (intento ${intento + 1}/${reintentosEco.length}): $e');
        }
        if (response.statusCode == 200) break;
        if (intento < reintentosEco.length - 1) await Future.delayed(reintentosEco[intento]);
      }
    }

    Logger.api('${response.statusCode} - Respuesta Apps Script: ${Logger.truncate(response.data?.toString() ?? '')}', isRequest: false);

    if (response.statusCode != 200) return (huboRedirect: huboRedirect, data: null);

    final raw = response.data;
    Map<String, dynamic>? data;
    if (raw is Map<String, dynamic>) {
      data = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }
    }
    // Token revocado o vencido que el teléfono sigue entregando: se pide uno
    // nuevo y se reintenta una sola vez (el servidor rechazó el pedido antes
    // de ejecutarlo, así que repetirlo no duplica nada).
    if (data != null && data['code'] == 'no_autenticado' && !tokenRenovado && renovadorToken != null) {
      Logger.warning('SheetsDataService: el servidor rechazó el token de Google; se pide uno nuevo y se reintenta.');
      String? nuevo;
      try {
        nuevo = await renovadorToken!();
      } catch (_) {
        nuevo = null;
      }
      if (nuevo != null) {
        return _postAppsScriptJson(
          payload,
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
          reintentosEco: reintentosEco,
          tokenRenovado: true,
        );
      }
    }
    if (data != null && data['code'] == 'acceso_revocado' && usuario != null) {
      _accesoRevocadoEnServidor = data['message']?.toString() ?? 'Tu acceso fue revocado.';
      Logger.warning('SheetsDataService: el servidor rechazó la escritura de $usuario: $_accesoRevocadoEnServidor');
      notifyListeners();
    }
    return (huboRedirect: huboRedirect, data: data);
  }

  /// Sincroniza de forma asíncrona la acción con la Web App de Google Apps Script (Opción A)
  /// Con [exigirConfirmacion], solo cuenta como OK una respuesta
  /// `{status: "success"}` del script: una respuesta `{status: "error"}`
  /// (p. ej. "Registro no encontrado") es un fallo.
  Future<bool> _postToAppsScript(
    Map<String, dynamic> payload, {
    bool exigirConfirmacion = false,
  }) async {
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
      Logger.object('Payload Apps Script [Hoja: $sheet, Acción: $action]', payload);

      final resultado = await _postAppsScriptJson(payload);

      // OK si se pudo confirmar la respuesta, o si al menos Apps Script
      // aceptó el POST (302) aunque no se haya podido leer el eco — la
      // acción ya quedó en cola/procesada del lado del servidor.
      final data = resultado.data;
      final isOk = exigirConfirmacion
          ? (data != null ? data['status'] == 'success' : resultado.huboRedirect)
          : (data != null || resultado.huboRedirect);
      if (isOk) {
        Logger.success('SheetsDataService: Sincronización exitosa en Google Sheets (Hoja: $sheet, Acción: $action).');
        return true;
      } else {
        Logger.error(
          'SheetsDataService: Falló sincronización con Google Sheets (Hoja: $sheet, Acción: $action).',
        );
        return false;
      }
    } catch (e, stackTrace) {
      Logger.error('SheetsDataService: Excepción al conectar con Apps Script', e, stackTrace);
      return false;
    }
  }

  /// Ejecutor transaccional de lotes atómicos (All-or-Nothing)
  late final SheetsBatchExecutor _batchExecutor = SheetsBatchExecutor(
    postJson: _postAppsScriptJson,
  );

  /// Ejecuta una transacción por lotes atómica (All-or-Nothing) en Google Apps Script.
  Future<BatchTransactionResult> executeBatchTransaction(BatchTransaction transaction) {
    return _batchExecutor.execute(transaction);
  }

  /// Como [_postToAppsScript], pero para creaciones: devuelve el ID real que
  /// asignó el servidor (ver `_siguienteIdServidor`/`ID_PREFIXES` en
  /// google_apps_script.js), que puede diferir del ID que se calculó acá en
  /// el cliente si otra sesión ya había avanzado la secuencia — ver
  /// docs/google/red-http.md. `null` si el servidor rechazó la creación
  /// (por ejemplo, una FK inválida) o si no se pudo confirmar la respuesta.
  Future<String?> _crearEnServidor(String sheet, Map<String, dynamic> data) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      Logger.warning('SheetsDataService: APPS_SCRIPT_URL no configurada. "$sheet" se guardó solo localmente.');
      return null;
    }
    final resultado = await _postAppsScriptJson({'action': 'create', 'sheet': sheet, 'data': data});
    final body = resultado.data;
    if (body == null) {
      Logger.error('SheetsDataService: no se pudo confirmar la creación en "$sheet".');
      return null;
    }
    if (body['status'] != 'success') {
      Logger.error('SheetsDataService: el servidor rechazó la creación en "$sheet": ${body['message']}');
      return null;
    }
    return body['id']?.toString();
  }

  String get nextGaleriaId {
    final maxId = _galeria.fold<int>(0, (prev, g) {
      final n = int.tryParse(g.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return n > prev ? n : prev;
    });
    return 'g${(maxId + 1).toString().padLeft(8, '0')}';
  }

  /// Resuelve el id de una foto (FK de Producto.fotoId) a su URL real,
  /// haciendo el JOIN lógico contra la hoja "galeria" — nunca se guarda la
  /// URL directamente en `inventario`.
  String? fotoUrlPorId(String? fotoId) {
    if (fotoId == null || fotoId.isEmpty) return null;
    return _galeria.where((g) => g.id == fotoId).firstOrNull?.url;
  }

  /// Sube una imagen a la carpeta de Google Drive configurada vía Web App y
  /// la registra como una fila nueva en "galeria". Devuelve el ID de esa
  /// fila (no la URL): eso es lo único que debe guardarse en
  /// `Producto.fotoId`. Las fotos nunca se reemplazan ni se borran de la
  /// galería — cada subida crea una fila nueva, así una foto usada por un
  /// producto que ya tuvo ventas nunca se pierde ni se pisa.
  Future<String?> subirFotoGaleria({
    required List<int> bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    final base64Data = base64Encode(bytes);

    // El candado global de doPost (LockService) puede estar ocupado por
    // otra ejecución todavía corriendo del lado del servidor (p.ej. un
    // intento anterior que el teléfono ya dio por perdido, pero que Apps
    // Script sigue procesando). En ese caso doPost devuelve de inmediato
    // "Servidor ocupado" SIN haber llegado a crear ningún archivo — es
    // seguro reintentar el POST completo desde cero.
    const reintentosPorCandadoOcupado = 3;
    Map<String, dynamic>? data;
    for (var intentoGlobal = 1; intentoGlobal <= reintentosPorCandadoOcupado; intentoGlobal++) {
      Logger.object('Payload Apps Script [upload_image, archivo: $fileName, ${bytes.length} bytes, intento $intentoGlobal/$reintentosPorCandadoOcupado]', {
        'action': 'upload_image',
        'fileName': fileName,
        'mimeType': mimeType,
      });

      final resultado = await _postAppsScriptJson(
        {
          'action': 'upload_image',
          'fileName': fileName,
          'mimeType': mimeType,
          'base64Data': base64Data,
        },
        // El payload en base64 puede ser grande y una red móvil real puede
        // tardar bastante en subirlo + procesarlo del lado del servidor —
        // se necesita mucho más margen que en el resto de las acciones.
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
        reintentosEco: const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1000),
          Duration(milliseconds: 2000),
          Duration(milliseconds: 3000),
          Duration(milliseconds: 4000),
          Duration(milliseconds: 5000),
        ],
      );

      final parsed = resultado.data;
      if (parsed == null) {
        Logger.error('subirFotoGaleria: no se pudo confirmar la subida. El archivo puede haberse subido igual a Drive.');
        return null;
      }

      final ocupado = parsed['status'] != 'success' &&
          (parsed['message']?.toString().toLowerCase().contains('ocupado') ?? false);
      if (ocupado && intentoGlobal < reintentosPorCandadoOcupado) {
        Logger.warning('subirFotoGaleria: servidor ocupado (candado de Apps Script), reintentando el POST completo...');
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      if (parsed['status'] != 'success' || parsed['fileUrl'] == null) {
        Logger.error('subirFotoGaleria: respuesta inesperada: $parsed');
        return null;
      }

      data = parsed;
      break;
    }

    if (data == null) return null;

    final nuevo = GaleriaItem(
      id: nextGaleriaId,
      url: data['fileUrl'] as String,
      driveFileId: (data['fileId'] ?? '').toString(),
      nombreArchivo: fileName,
      fechaSubida: DateTime.now(),
    );
    _galeria.insert(0, nuevo);
    notifyListeners();

    // Sin la fila en "galeria", `Producto.fotoId` apuntaría a algo que no
    // existe: si no se confirma, se descarta (la foto queda solo en Drive).
    final String idReal;
    try {
      idReal = await _crearConRollback(
        'galeria',
        Map.of(nuevo.toMap())..remove('id'),
        revertir: () => _galeria.remove(nuevo),
      );
    } on StateError {
      Logger.warning('SheetsDataService: foto subida a Drive pero no se pudo registrar en "galeria".');
      return null;
    }
    final idx = _galeria.indexOf(nuevo);
    if (idx != -1) {
      _galeria[idx] = GaleriaItem(
        id: idReal,
        url: nuevo.url,
        driveFileId: nuevo.driveFileId,
        nombreArchivo: nuevo.nombreArchivo,
        fechaSubida: nuevo.fechaSubida,
      );
      notifyListeners();
    }
    return idReal;
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

  /// Registra el cliente en la organización actual. El ID lo asigna el
  /// servidor. Lanza [StateError] (y no deja nada en el teléfono) si Sheets
  /// no lo confirma.
  Future<void> addCliente(Cliente cliente) async {
    final stamped = cliente.copyWith(organizacionId: _orgActualOrDefault);
    _clientes.add(stamped);
    notifyListeners();
    final idReal = await _crearConRollback(
      'clientes',
      Map.of(stamped.toMap())..remove('id'),
      revertir: () => _clientes.remove(stamped),
    );
    final idx = _clientes.indexOf(stamped);
    if (idx != -1) _clientes[idx] = stamped.copyWith(id: idReal);
    _logAudit(
      hoja: 'clientes',
      celda: 'A${_clientes.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$idReal (${stamped.nombre})',
      accion: 'creacion_cliente',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Alta de cliente con teléfono ${stamped.telefono}',
    );
    notifyListeners();
  }

  /// Actualiza el cliente. Conserva su organización y fecha de registro.
  /// Lanza [StateError] (y revierte) si Sheets no lo confirma.
  Future<void> updateCliente(Cliente cliente) async {
    final index = _clientes.indexWhere((c) => c.id == cliente.id);
    if (index == -1) throw ArgumentError('No se encontró el cliente ${cliente.id}.');
    final old = _clientes[index];
    final actualizado = cliente.copyWith(
      organizacionId: old.organizacionId,
      fechaRegistro: old.fechaRegistro,
      activo: old.activo, // el estado solo cambia con cambiarEstadoCliente
    );
    _clientes[index] = actualizado;
    _logAudit(
      hoja: 'clientes',
      celda: 'A${index + 2}',
      valorAnterior: '${old.nombre} | ${old.telefono} | ${old.email}',
      valorNuevo: '${actualizado.nombre} | ${actualizado.telefono} | ${actualizado.email}',
      accion: 'actualizacion_cliente',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Modificación de datos de cliente ${actualizado.id}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'clientes', 'id': actualizado.id, 'data': actualizado.toMap()},
      revertir: () {
        final i = _clientes.indexOf(actualizado);
        if (i != -1) _clientes[i] = old;
      },
    );
  }

  /// Activa o inactiva un cliente. Inactivo se conserva (ventas, historial)
  /// pero no aparece para ventas nuevas. Revierte y lanza [StateError] si
  /// Sheets no lo confirma.
  Future<void> cambiarEstadoCliente(String id, {required bool activo}) async {
    final index = _clientes.indexWhere((c) => c.id == id);
    if (index == -1) throw ArgumentError('No se encontró el cliente $id.');
    final old = _clientes[index];
    if (old.activo == activo) return;
    final actualizado = old.copyWith(activo: activo);
    _clientes[index] = actualizado;
    _logAudit(
      hoja: 'clientes',
      celda: 'J${index + 2}',
      valorAnterior: old.activo ? 'activo' : 'inactivo',
      valorNuevo: activo ? 'activo' : 'inactivo',
      accion: activo ? 'activacion_cliente' : 'inactivacion_cliente',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Cliente $id ${activo ? 'activado' : 'inactivado'}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'clientes', 'id': id, 'data': {'status': activo}},
      revertir: () {
        final i = _clientes.indexOf(actualizado);
        if (i != -1) _clientes[i] = old;
      },
    );
  }

  /// Motivo por el que un cliente no se puede eliminar, o `null` si se puede.
  /// Un cliente con ventas o con historial de saldo a favor no se borra:
  /// esas filas lo referencian por FK y quedarían huérfanas.
  String? motivoNoEliminableCliente(String id) {
    final ventas = _ventas.where((v) => v.clienteId == id).length;
    if (ventas > 0) {
      return 'Tiene $ventas ${ventas == 1 ? 'venta registrada' : 'ventas registradas'}.';
    }
    if (_creditosClientes.any((c) => c.clienteId == id)) {
      return 'Tiene historial de saldo a favor.';
    }
    return null;
  }

  /// Elimina el cliente. Lanza [ArgumentError] si no existe o si
  /// [motivoNoEliminableCliente] lo impide, y [StateError] (revirtiendo) si
  /// Sheets no lo confirma.
  Future<void> deleteCliente(String id) async {
    final motivo = motivoNoEliminableCliente(id);
    if (motivo != null) throw ArgumentError('No se puede eliminar el cliente. $motivo');
    final index = _clientes.indexWhere((c) => c.id == id);
    if (index == -1) throw ArgumentError('No se encontró el cliente $id.');
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
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'clientes', 'id': id},
      revertir: () => _clientes.insert(index.clamp(0, _clientes.length), old),
    );
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

  /// Registra el producto en la organización actual. El ID lo asigna el
  /// servidor. Lanza [StateError] (sin dejar nada) si Sheets no lo confirma.
  Future<void> addProducto(Producto producto) async {
    final stamped = producto.copyWith(organizacionId: _orgActualOrDefault);
    _productos.add(stamped);
    notifyListeners();
    final idReal = await _crearConRollback(
      'inventario',
      Map.of(stamped.toMap())..remove('id'),
      revertir: () => _productos.remove(stamped),
    );
    final idx = _productos.indexOf(stamped);
    if (idx != -1) _productos[idx] = stamped.copyWith(id: idReal);
    _logAudit(
      hoja: 'inventario',
      celda: 'A${_productos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$idReal (${stamped.nombre})',
      accion: 'creacion_producto',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Nuevo producto en inventario. Stock inicial: ${stamped.cantidad}',
    );
    notifyListeners();
  }

  /// Aplica [cambio] sobre el producto [id] y envía solo [datos] (los campos
  /// que cambian): mandar el producto completo pisaba el stock con un valor
  /// viejo si otro dispositivo había vendido en el ínterin.
  Future<void> _actualizarProducto(
    String id,
    Producto Function(Producto actual) cambio,
    Map<String, dynamic> Function(Producto nuevo) datos, {
    required String accion,
    required String observaciones,
  }) async {
    final index = _productos.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('No se encontró el producto $id.');
    final old = _productos[index];
    final nuevo = cambio(old).copyWith(id: old.id, organizacionId: old.organizacionId);
    _productos[index] = nuevo;
    _logAudit(
      hoja: 'inventario',
      celda: 'A${index + 2}',
      valorAnterior: '${old.nombre}, ${old.talla}, USD ${old.precioUsd}, stock ${old.cantidad}',
      valorNuevo: '${nuevo.nombre}, ${nuevo.talla}, USD ${nuevo.precioUsd}, stock ${nuevo.cantidad}',
      accion: accion,
      norma: 'ISO 8000 §4.2',
      observaciones: observaciones,
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'inventario', 'id': id, 'data': datos(nuevo)},
      revertir: () {
        final i = _productos.indexOf(nuevo);
        if (i != -1) _productos[i] = old;
      },
    );
  }

  /// Edita los datos del producto desde el formulario (incluida la cantidad
  /// que escribió el usuario). Conserva ID y organización.
  Future<void> updateProducto(Producto producto) => _actualizarProducto(
        producto.id,
        (actual) => producto,
        (p) => {
          'cantidad': p.cantidad,
          'nombre': p.nombre,
          'marca': p.marca,
          'modelo': p.modelo,
          'talla': p.talla,
          'precio_usd': p.precioUsd,
          'foto_id': p.fotoId ?? '',
        },
        accion: 'actualizacion_producto',
        observaciones: 'Actualización de producto ${producto.id}',
      );

  /// Cambia solo la foto del producto.
  Future<void> actualizarFotoProducto(String id, String? fotoId) => _actualizarProducto(
        id,
        (actual) => actual.copyWith(fotoId: fotoId, borrarFoto: fotoId == null),
        (p) => {'foto_id': p.fotoId ?? ''},
        accion: 'actualizacion_foto_producto',
        observaciones: 'Cambio de foto del producto $id',
      );

  /// Ajustes de stock enviados y todavía sin respuesta, por producto.
  final Map<String, int> _ajustesStockEnCurso = {};

  /// Suma [delta] al stock. Se envía la DIFERENCIA (operación `increment`):
  /// el servidor la aplica sobre el stock que tenga en ese momento, así un
  /// ajuste no pisa una venta hecha desde otro dispositivo ni otro toque
  /// rápido que llegue desordenado. Si Sheets no lo confirma, se deshace
  /// solo este ajuste y se lanza [StateError].
  Future<void> adjustStock(String id, int delta) async {
    final index = _productos.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('No se encontró el producto $id.');
    if (delta == 0) return;
    final old = _productos[index];
    final aplicado = (old.cantidad + delta).clamp(0, 999999) - old.cantidad;
    _productos[index] = old.copyWith(cantidad: old.cantidad + aplicado);
    _ajustesStockEnCurso[id] = (_ajustesStockEnCurso[id] ?? 0) + 1;
    _logAudit(
      hoja: 'inventario',
      celda: 'B${index + 2}',
      valorAnterior: 'stock ${old.cantidad}',
      valorNuevo: 'stock ${old.cantidad + aplicado}',
      accion: 'ajuste_stock',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Ajuste manual de stock ($delta) del producto $id',
    );
    notifyListeners();

    final res = await executeBatchTransaction(BatchTransaction(
      transactionId: 'tx_stock_${id}_${DateTime.now().microsecondsSinceEpoch}',
      operations: [
        BatchOperation.increment(sheet: 'inventario', id: id, field: 'cantidad', delta: delta, min: 0),
      ],
    ));
    final restantes = (_ajustesStockEnCurso[id] ?? 1) - 1;
    if (restantes <= 0) {
      _ajustesStockEnCurso.remove(id);
    } else {
      _ajustesStockEnCurso[id] = restantes;
    }
    final i = _productos.indexWhere((p) => p.id == id);

    if (!res.isSuccess) {
      if (i != -1) {
        final p = _productos[i];
        _productos[i] = p.copyWith(cantidad: (p.cantidad - aplicado).clamp(0, 999999));
      }
      notifyListeners();
      await _lanzarErrorDeLote(res, 'ajustar el stock', 'revisá el stock del producto');
    }

    // Con otros ajustes todavía en viaje, el valor del servidor no los
    // incluye: se deja el local, y lo corrige la última respuesta.
    final enServidor = res.valorIncrementado('inventario', id)?.toInt();
    if (i != -1 && restantes <= 0 && enServidor != null) {
      _productos[i] = _productos[i].copyWith(cantidad: enServidor);
      notifyListeners();
    }
  }

  /// Motivo por el que un producto no se puede eliminar, o `null`: un
  /// producto vendido quedaría huérfano en las facturas (venta_items).
  String? motivoNoEliminableProducto(String id) {
    final vendidos = _ventaItems.where((vi) => vi.itemId == id).length;
    return vendidos > 0
        ? 'Figura en $vendidos ${vendidos == 1 ? 'renglón de factura' : 'renglones de facturas'}.'
        : null;
  }

  Future<void> deleteProducto(String id) async {
    final motivo = motivoNoEliminableProducto(id);
    if (motivo != null) throw ArgumentError('No se puede eliminar el producto. $motivo');
    final index = _productos.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('No se encontró el producto $id.');
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
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'inventario', 'id': id},
      revertir: () => _productos.insert(index.clamp(0, _productos.length), old),
    );
  }

  // ===========================================================================
  // NOTIFICACIONES FCM (hojas dispositivos y notificaciones)
  // ===========================================================================

  /// Acción del servidor que no modifica datos de este teléfono (no hay nada
  /// que revertir): exige `{status: "success"}` y devuelve la respuesta, o
  /// lanza [StateError] con el mensaje del servidor.
  Future<Map<String, dynamic>> _accionEnServidor(Map<String, dynamic> payload) async {
    final url = appsScriptUrl;
    if (url == null || url.trim().isEmpty) {
      throw StateError('No hay conexión con Google Sheets configurada.');
    }
    final respuesta = await _postAppsScriptJson(payload);
    final data = respuesta.data;
    if (data == null) {
      throw StateError('No se pudo confirmar la respuesta del servidor (${payload['action']}).');
    }
    if (data['status'] != 'success') {
      final mensaje = data['message']?.toString() ?? 'El servidor rechazó la acción ${payload['action']}.';
      if (data['code'] == 'limite_notificaciones') throw LimiteNotificacionesAgotado(mensaje);
      throw StateError(mensaje);
    }
    return data;
  }

  /// Registra (o actualiza) el token FCM de este dispositivo para el usuario
  /// de la sesión. El servidor toma la organización de la membresía actual,
  /// no la que mande la app. Lanza [StateError] si falla.
  Future<void> registrarDispositivo({required String token, required String plataforma}) async {
    if (_currentUsuarioEmail == null) throw StateError('No hay usuario en la sesión.');
    await _accionEnServidor({
      'action': 'registrar_dispositivo',
      'sheet': 'dispositivos',
      'data': {'token': token, 'plataforma': plataforma},
    });
  }

  /// Borra el token de este dispositivo (al cerrar sesión). [usuarioEmail]
  /// se pasa explícito porque al cerrar sesión el usuario actual ya puede
  /// estar en null.
  Future<void> eliminarDispositivo({required String token, required String usuarioEmail}) async {
    await _accionEnServidor({
      'action': 'eliminar_dispositivo',
      'sheet': 'dispositivos',
      'usuario_sesion': usuarioEmail.trim().toLowerCase(),
      'data': {'token': token},
    });
  }

  /// Envía una notificación FCM. Cualquier usuario con acceso puede enviar a
  /// cualquier destino ([DestinoNotificacion]); el servidor valida el
  /// remitente, resuelve los dispositivos, envía y deja el registro en la
  /// hoja "notificaciones". Lanza [ArgumentError] si los datos no son
  /// válidos y [StateError] si el servidor la rechaza.
  Future<ResultadoEnvioNotificacion> enviarNotificacion({
    required DestinoNotificacion destino,
    required String titulo,
    required String cuerpo,
    Map<String, String> datos = const {},
  }) async {
    final t = titulo.trim();
    final c = cuerpo.trim();
    if (t.isEmpty || t.length > 100) throw ArgumentError('El título es obligatorio (hasta 100 caracteres).');
    if (c.isEmpty || c.length > 500) throw ArgumentError('El mensaje es obligatorio (hasta 500 caracteres).');
    final errorDestino = destino.error;
    if (errorDestino != null) throw ArgumentError(errorDestino);
    if (_currentUsuarioEmail == null) throw StateError('No hay usuario en la sesión.');

    final r = await _accionEnServidor({
      'action': 'enviar_notificacion',
      'sheet': 'notificaciones',
      'data': {...destino.toMap(), 'titulo': t, 'cuerpo': c, 'datos': datos},
    });
    _logAudit(
      hoja: 'notificaciones',
      celda: 'A',
      valorAnterior: 'null',
      valorNuevo: '${r['id']}: $t',
      accion: 'envio_notificacion',
      norma: 'ISO/IEC 27001 §5.14',
      observaciones: 'Notificación ${destino.alcance.name}: ${r['enviados']} enviadas, ${r['fallidos']} fallidas',
    );
    return ResultadoEnvioNotificacion(
      id: r['id']?.toString() ?? '',
      enviados: (r['enviados'] as num?)?.toInt() ?? 0,
      fallidos: (r['fallidos'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ejecuta una copia de seguridad manual en el servidor (Apps Script).
  /// Guarda la hoja en <carpeta privada>/Respaldos y deja registro en audit_log.
  Future<Map<String, dynamic>> respaldarHojaManual() async {
    final r = await _accionEnServidor({
      'action': 'respaldar_hoja',
      'sheet': 'sistema',
    });
    return r;
  }

  /// Cambia cada vez que llega un aviso de que los límites o el uso de las
  /// notificaciones cambiaron (push silencioso o al entrar al módulo): las
  /// pantallas abiertas vuelven a consultar el cupo.
  int _versionNotificaciones = 0;
  int get versionNotificaciones => _versionNotificaciones;

  /// Relee lo que cambió en el módulo de notificaciones: con [config], las
  /// hojas del módulo (límites, plantillas y tipos). Siempre avisa a las
  /// pantallas abiertas ([versionNotificaciones]) para que consulten el cupo.
  Future<void> releerNotificaciones({bool config = false}) async {
    if (config && !_isLoading) {
      try {
        await Future.wait([
          _fetchSheet('config_notificaciones', _parseConfigNotificaciones,
              expectedHeaders: const ['id', 'organizacion_id', 'periodo', 'limite_por_usuario', 'limite_organizacion']),
          _fetchSheet('tipos_notificacion', _parseTiposNotificacion, expectedHeaders: const ['id', 'nombre', 'status']),
          _fetchSheet('plantillas_notificacion', _parsePlantillasNotificacion,
              expectedHeaders: const ['id', 'organizacion_id', 'tipo_id', 'titulo', 'cuerpo']),
        ]);
      } catch (e) {
        Logger.warning('SheetsDataService: no se pudieron releer las hojas de notificaciones: $e');
      }
    }
    _versionNotificaciones++;
    notifyListeners();
  }

  /// Clientes activos de la organización actual con un correo válido: los
  /// que pueden recibir un correo de la organización.
  List<Cliente> get clientesConEmail =>
      List.unmodifiable(clientesActivos.where((c) => Organizacion.formatoEmail.hasMatch(c.email.trim())));

  /// Envía un correo de la organización actual a sus clientes ([todos] o
  /// los de [clienteIds]): asunto y mensaje de una notificación guardada. Sale
  /// con el nombre de la organización y "Responder a" su correo. Lanza
  /// [ArgumentError] si faltan datos y [StateError] si el servidor lo rechaza.
  Future<ResultadoEnvioCorreo> enviarCorreoClientes({
    required String asunto,
    required String cuerpo,
    bool todos = false,
    Set<String> clienteIds = const {},
  }) async {
    final a = asunto.trim();
    final c = cuerpo.trim();
    if (a.isEmpty || a.length > PlantillaNotificacion.maxTitulo) throw ArgumentError('El asunto es obligatorio (hasta 100 caracteres).');
    if (c.isEmpty || c.length > PlantillaNotificacion.maxCuerpo) throw ArgumentError('El mensaje es obligatorio (hasta 500 caracteres).');
    if (!todos && clienteIds.isEmpty) throw ArgumentError('Elegí al menos un cliente.');
    if (_currentUsuarioEmail == null) throw StateError('No hay usuario en la sesión.');
    final r = await _accionEnServidor({
      'action': 'enviar_correo',
      'sheet': 'correos',
      'data': {'asunto': a, 'cuerpo': c, 'todos': todos, if (!todos) 'cliente_ids': clienteIds.toList()},
    });
    _logAudit(
      hoja: 'correos',
      celda: 'A',
      valorAnterior: 'null',
      valorNuevo: '${r['id']}: $a',
      accion: 'envio_correo_clientes',
      norma: 'ISO/IEC 27001 §5.14',
      observaciones: 'Correo a clientes: ${r['enviados']} enviados, ${r['fallidos']} fallidos',
    );
    return ResultadoEnvioCorreo(
      id: r['id']?.toString() ?? '',
      enviados: (r['enviados'] as num?)?.toInt() ?? 0,
      fallidos: (r['fallidos'] as num?)?.toInt() ?? 0,
      restantes: (r['restantes'] as num?)?.toInt(),
    );
  }

  /// Correos que Google todavía permite enviar hoy desde el Apps Script.
  Future<int> cupoCorreo() async {
    if (_currentUsuarioEmail == null) throw StateError('No hay usuario en la sesión.');
    final r = await _accionEnServidor({'action': 'uso_correo', 'sheet': 'correos'});
    final restantes = r['restantes'];
    if (restantes is! num) throw StateError('El servidor no informó el cupo de correos.');
    return restantes.toInt();
  }

  /// Límites y uso del período actual para el usuario de la sesión (los
  /// cuenta el servidor sobre la hoja "notificaciones"). Lanza [StateError]
  /// si falla.
  Future<UsoNotificaciones> usoNotificaciones() async {
    if (_currentUsuarioEmail == null) throw StateError('No hay usuario en la sesión.');
    final r = await _accionEnServidor({'action': 'uso_notificaciones', 'sheet': 'notificaciones'});
    int entero(String clave) => (r[clave] as num?)?.toInt() ?? 0;
    return UsoNotificaciones(
      periodo: PeriodoNotificaciones.desde(r['periodo']?.toString() ?? '') ?? ConfigNotificaciones.periodoPorDefecto,
      limitePorUsuario: entero('limite_por_usuario'),
      limiteOrganizacion: entero('limite_organizacion'),
      usadosUsuario: entero('usados_usuario'),
      usadosOrganizacion: entero('usados_organizacion'),
      renueva: DateTime.tryParse(r['renueva']?.toString() ?? '')?.toLocal(),
    );
  }

  // ===========================================================================
  // DATOS BANCARIOS (hojas cuentas_bancarias y bancos)
  // ===========================================================================

  /// Relee los bancos y los datos bancarios (al entrar al módulo: pudieron
  /// cambiar desde otro teléfono o en la hoja).
  Future<void> releerDatosBancarios() async {
    if (_isLoading) return;
    try {
      await Future.wait([
        _fetchSheet('bancos', _parseBancos, expectedHeaders: const ['id', 'codigo', 'nombre', 'status']),
        _fetchSheet('cuentas_bancarias', _parseCuentasBancarias,
            expectedHeaders: const ['id', 'organizacion_id', 'tipo', 'banco_id', 'titular']),
      ]);
    } catch (e) {
      Logger.warning('SheetsDataService: no se pudieron releer los datos bancarios: $e');
    }
    notifyListeners();
  }

  /// Motivo por el que [cuenta] no es válida (mismas reglas que el servidor),
  /// o `null`. [excluirId]: la propia cuenta, al editar.
  String? motivoCuentaBancariaInvalida(CuentaBancaria cuenta, {String? excluirId}) {
    final banco = bancoPorId(cuenta.bancoId);
    if (banco == null) return 'Elegí el banco.';
    if (cuenta.titular.trim().isEmpty || cuenta.titular.trim().length > 80) {
      return 'El titular es obligatorio (hasta 80 caracteres).';
    }
    final errorDoc = DocumentoIdentidad.validar(cuenta.tipoDocumento, cuenta.documento);
    if (errorDoc != null) return errorDoc;
    final otras = _cuentasBancarias.where(
        (c) => c.organizacionId == cuenta.organizacionId && c.id != excluirId && c.tipo == cuenta.tipo);
    if (cuenta.tipo == TipoCuentaBancaria.transferencia) {
      if (!RegExp(r'^\d{20}$').hasMatch(cuenta.numeroCuenta)) return 'El número de cuenta tiene que tener 20 dígitos.';
      if (!cuenta.numeroCuenta.startsWith(banco.codigo)) {
        return 'El número de cuenta empieza con ${cuenta.numeroCuenta.substring(0, 4)}, '
            'pero el código de ${banco.nombre} es ${banco.codigo}.';
      }
      if (cuenta.modalidad == null) return 'Elegí el tipo de cuenta: corriente o ahorro.';
      if (otras.any((c) => c.numeroCuenta == cuenta.numeroCuenta)) return 'Esa cuenta ya está registrada.';
    } else {
      if (!RegExp(r'^04\d{9}$').hasMatch(cuenta.telefono)) {
        return 'El teléfono de pago móvil tiene que ser un celular (04XX-XXXXXXX).';
      }
      if (otras.any((c) => c.bancoId == cuenta.bancoId && c.telefono == cuenta.telefono)) {
        return 'Ese pago móvil (banco y teléfono) ya está registrado.';
      }
    }
    return null;
  }

  /// Registra un dato bancario en la organización actual y lo devuelve con
  /// el ID del servidor. Lanza [ArgumentError] si no es válido y
  /// [StateError] (y revierte) si Sheets no lo confirma.
  Future<CuentaBancaria> addCuentaBancaria(CuentaBancaria datos) async {
    final org = _currentOrganizacionId;
    if (org == null || org.isEmpty) throw StateError('No hay una organización seleccionada.');
    final nueva = CuentaBancaria(
      id: '',
      organizacionId: org,
      tipo: datos.tipo,
      bancoId: datos.bancoId,
      titular: datos.titular.trim(),
      tipoDocumento: datos.tipoDocumento,
      documento: datos.documento,
      numeroCuenta: datos.numeroCuenta,
      modalidad: datos.modalidad,
      telefono: datos.telefono,
      activa: datos.activa,
      actualizadoEn: DateTime.now().toUtc().toIso8601String(),
    );
    final motivo = motivoCuentaBancariaInvalida(nueva);
    if (motivo != null) throw ArgumentError(motivo);
    _cuentasBancarias.add(nueva);
    notifyListeners();
    final id = await _crearConRollback('cuentas_bancarias', Map.of(nueva.toMap())..remove('id'),
        revertir: () => _cuentasBancarias.remove(nueva));
    final confirmada = nueva.copyWith(id: id);
    final i = _cuentasBancarias.indexOf(nueva);
    if (i != -1) _cuentasBancarias[i] = confirmada;
    notifyListeners();
    return confirmada;
  }

  /// Reemplaza los datos de una cuenta (conserva ID y organización).
  Future<void> updateCuentaBancaria(CuentaBancaria cuenta) async {
    final index = _cuentasBancarias.indexWhere((c) => c.id == cuenta.id);
    if (index == -1) throw ArgumentError('El dato bancario ya no existe.');
    final anterior = _cuentasBancarias[index];
    final actualizada = CuentaBancaria(
      id: anterior.id,
      organizacionId: anterior.organizacionId,
      tipo: cuenta.tipo,
      bancoId: cuenta.bancoId,
      titular: cuenta.titular.trim(),
      tipoDocumento: cuenta.tipoDocumento,
      documento: cuenta.documento,
      numeroCuenta: cuenta.numeroCuenta,
      modalidad: cuenta.modalidad,
      telefono: cuenta.telefono,
      activa: cuenta.activa,
      actualizadoEn: DateTime.now().toUtc().toIso8601String(),
    );
    if (actualizada.copyWith(actualizadoEn: anterior.actualizadoEn) == anterior) return; // sin cambios
    final motivo = motivoCuentaBancariaInvalida(actualizada, excluirId: anterior.id);
    if (motivo != null) throw ArgumentError(motivo);
    _cuentasBancarias[index] = actualizada;
    notifyListeners();
    await _sincronizarConRollback(
      {
        'action': 'update',
        'sheet': 'cuentas_bancarias',
        'id': anterior.id,
        'data': Map.of(actualizada.toMap())..remove('id')..remove('organizacion_id'),
      },
      revertir: () {
        final i = _cuentasBancarias.indexOf(actualizada);
        if (i != -1) _cuentasBancarias[i] = anterior;
      },
    );
  }

  /// Elimina un dato bancario. Lanza [StateError] (y lo repone) si Sheets no
  /// lo confirma.
  Future<void> deleteCuentaBancaria(String id) async {
    final index = _cuentasBancarias.indexWhere((c) => c.id == id);
    if (index == -1) throw ArgumentError('El dato bancario ya no existe.');
    final anterior = _cuentasBancarias.removeAt(index);
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'cuentas_bancarias', 'id': id},
      revertir: () => _cuentasBancarias.insert(index.clamp(0, _cuentasBancarias.length), anterior),
    );
  }

  /// Agrega un tipo de notificación al catálogo y lo devuelve con el ID que
  /// le asignó el servidor. Lanza [ArgumentError] si el nombre está vacío o
  /// repetido, y [StateError] (y revierte) si Sheets no lo confirma.
  Future<TipoNotificacion> addTipoNotificacion(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty || limpio.length > 40) throw ArgumentError('El nombre del tipo es obligatorio (hasta 40 caracteres).');
    if (_tiposNotificacion.any((t) => t.nombre.toLowerCase() == limpio.toLowerCase())) {
      throw ArgumentError('Ya existe el tipo "$limpio".');
    }
    final nuevo = TipoNotificacion(id: '', nombre: limpio);
    _tiposNotificacion.add(nuevo);
    notifyListeners();
    final id = await _crearConRollback('tipos_notificacion', Map.of(nuevo.toMap())..remove('id'),
        revertir: () => _tiposNotificacion.remove(nuevo));
    final confirmado = TipoNotificacion(id: id, nombre: limpio);
    final i = _tiposNotificacion.indexOf(nuevo);
    if (i != -1) _tiposNotificacion[i] = confirmado;
    notifyListeners();
    return confirmado;
  }

  void _validarPlantilla({required String tipoId, required String titulo, required String cuerpo}) {
    if (!_tiposNotificacion.any((t) => t.id == tipoId)) throw ArgumentError('Elegí un tipo de notificación.');
    if (titulo.isEmpty || titulo.length > PlantillaNotificacion.maxTitulo) {
      throw ArgumentError('El título es obligatorio (hasta ${PlantillaNotificacion.maxTitulo} caracteres).');
    }
    if (cuerpo.isEmpty || cuerpo.length > PlantillaNotificacion.maxCuerpo) {
      throw ArgumentError('El mensaje es obligatorio (hasta ${PlantillaNotificacion.maxCuerpo} caracteres).');
    }
  }

  /// Guarda una notificación para reutilizar en la organización actual. La
  /// devuelve con el ID del servidor. Lanza [ArgumentError] si los datos no
  /// son válidos y [StateError] (y revierte) si Sheets no lo confirma.
  Future<PlantillaNotificacion> addPlantillaNotificacion({
    required String tipoId,
    required String titulo,
    required String cuerpo,
  }) async {
    final org = _currentOrganizacionId;
    if (org == null || org.isEmpty) throw StateError('No hay una organización seleccionada.');
    final t = titulo.trim();
    final c = cuerpo.trim();
    _validarPlantilla(tipoId: tipoId, titulo: t, cuerpo: c);
    final nueva = PlantillaNotificacion(
      id: '',
      organizacionId: org,
      tipoId: tipoId,
      titulo: t,
      cuerpo: c,
      creadoPor: _currentUsuarioEmail ?? '',
      actualizadoEn: DateTime.now().toUtc().toIso8601String(),
    );
    _plantillasNotificacion.insert(0, nueva);
    notifyListeners();
    final id = await _crearConRollback('plantillas_notificacion', Map.of(nueva.toMap())..remove('id'),
        revertir: () => _plantillasNotificacion.remove(nueva));
    final confirmada = nueva.copyWith(id: id);
    final i = _plantillasNotificacion.indexOf(nueva);
    if (i != -1) _plantillasNotificacion[i] = confirmada;
    notifyListeners();
    return confirmada;
  }

  /// Edita tipo, título y mensaje de una notificación guardada (conserva ID,
  /// organización y autor). Lanza [ArgumentError] / [StateError] como el alta.
  Future<void> updatePlantillaNotificacion(
    String id, {
    required String tipoId,
    required String titulo,
    required String cuerpo,
  }) async {
    final index = _plantillasNotificacion.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('La notificación ya no existe.');
    final t = titulo.trim();
    final c = cuerpo.trim();
    _validarPlantilla(tipoId: tipoId, titulo: t, cuerpo: c);
    final anterior = _plantillasNotificacion[index];
    if (anterior.tipoId == tipoId && anterior.titulo == t && anterior.cuerpo == c) return;
    final actualizada = anterior.copyWith(
        tipoId: tipoId, titulo: t, cuerpo: c, actualizadoEn: DateTime.now().toUtc().toIso8601String());
    _plantillasNotificacion[index] = actualizada;
    notifyListeners();
    await _sincronizarConRollback(
      {
        'action': 'update',
        'sheet': 'plantillas_notificacion',
        'id': id,
        'data': {'tipo_id': tipoId, 'titulo': t, 'cuerpo': c},
      },
      revertir: () {
        final i = _plantillasNotificacion.indexOf(actualizada);
        if (i != -1) _plantillasNotificacion[i] = anterior;
      },
    );
  }

  /// Elimina una notificación guardada (las ya enviadas siguen en la hoja
  /// "notificaciones"). Lanza [StateError] (y la repone) si Sheets no lo confirma.
  Future<void> deletePlantillaNotificacion(String id) async {
    final index = _plantillasNotificacion.indexWhere((p) => p.id == id);
    if (index == -1) throw ArgumentError('La notificación ya no existe.');
    final anterior = _plantillasNotificacion.removeAt(index);
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'plantillas_notificacion', 'id': id},
      revertir: () => _plantillasNotificacion.insert(index.clamp(0, _plantillasNotificacion.length), anterior),
    );
  }

  /// Guarda los límites de envío de notificaciones de una organización: crea
  /// su fila si todavía no tiene, o edita la existente (una por organización).
  /// Lanza [ArgumentError] si los valores no son válidos y [StateError] (y
  /// revierte) si Sheets no lo confirma.
  Future<void> guardarConfigNotificaciones({
    required String organizacionId,
    required PeriodoNotificaciones periodo,
    required int limitePorUsuario,
    required int limiteOrganizacion,
  }) async {
    if (!_organizaciones.any((o) => o.id == organizacionId)) {
      throw ArgumentError('La organización ya no existe.');
    }
    for (final l in [limitePorUsuario, limiteOrganizacion]) {
      if (l < 0 || l > ConfigNotificaciones.limiteMaximo) {
        throw ArgumentError('Los límites van de 0 (sin límite) a ${ConfigNotificaciones.limiteMaximo}.');
      }
    }
    final autor = _currentUsuarioEmail ?? '';
    final idx = _configNotificaciones.indexWhere((c) => c.organizacionId == organizacionId);
    if (idx != -1) {
      final anterior = _configNotificaciones[idx];
      if (anterior.periodo == periodo &&
          anterior.limitePorUsuario == limitePorUsuario &&
          anterior.limiteOrganizacion == limiteOrganizacion) {
        return; // sin cambios
      }
      final actualizada = anterior.copyWith(
        periodo: periodo,
        limitePorUsuario: limitePorUsuario,
        limiteOrganizacion: limiteOrganizacion,
        actualizadoPor: autor,
        actualizadoEn: DateTime.now().toUtc().toIso8601String(),
      );
      _configNotificaciones[idx] = actualizada;
      notifyListeners();
      await _sincronizarConRollback(
        {'action': 'update', 'sheet': 'config_notificaciones', 'id': actualizada.id, 'data': actualizada.toMap()},
        revertir: () {
          final i = _configNotificaciones.indexOf(actualizada);
          if (i != -1) _configNotificaciones[i] = anterior;
        },
      );
      return;
    }
    final nueva = ConfigNotificaciones(
      id: '',
      organizacionId: organizacionId,
      periodo: periodo,
      limitePorUsuario: limitePorUsuario,
      limiteOrganizacion: limiteOrganizacion,
      actualizadoPor: autor,
      actualizadoEn: DateTime.now().toUtc().toIso8601String(),
    );
    _configNotificaciones.add(nueva);
    notifyListeners();
    final idReal = await _crearConRollback(
      'config_notificaciones',
      Map.of(nueva.toMap())..remove('id'),
      revertir: () => _configNotificaciones.remove(nueva),
    );
    final i = _configNotificaciones.indexOf(nueva);
    if (i != -1) _configNotificaciones[i] = nueva.copyWith(id: idReal);
    notifyListeners();
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

  /// Registra una venta completa con sus ítems, ajuste de inventario y abono inicial
  /// en un único lote atómico transaccional (All-or-Nothing).
  /// Si falla la red o el backend rechaza la transacción, la memoria local queda intacta.
  /// Alias de [addVenta] (nombre anterior).
  Future<void> addVentaAtomica({
    required String clienteId,
    required List<({String productoId, int cantidad, double precioUsd})> items,
    required String metodoPagoId,
    double comisionPagoMovilBs = 0.0,
    required double abonoUsd,
    bool usarTasaManual = false,
  }) =>
      addVenta(
        clienteId: clienteId,
        items: items,
        metodoPagoId: metodoPagoId,
        comisionPagoMovilBs: comisionPagoMovilBs,
        abonoUsd: abonoUsd,
        usarTasaManual: usarTasaManual,
      );

  /// Registra una venta (cabecera, ítems, descuento de stock, deuda del
  /// cliente, abono inicial y auditoría) en UN lote atómico: o se guarda
  /// todo en Sheets o nada. Los datos del teléfono se tocan solo después de
  /// la confirmación. Lanza [StateError] si el lote falla; si no hubo
  /// respuesta, antes relee Sheets (pudo haberse aplicado).
  Future<void> addVenta({
    required String clienteId,
    required List<({String productoId, int cantidad, double precioUsd})> items,
    required String metodoPagoId,
    double comisionPagoMovilBs = 0.0,
    required double abonoUsd,
    bool usarTasaManual = false,
  }) async {
    assert(items.isNotEmpty, 'Una factura necesita al menos un ítem');

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

    final nuevosItems = <VentaItem>[];
    final unidadesVendidas = <String, int>{};
    for (final it in items) {
      nuevosItems.add(VentaItem(
        id: nextVentaItemId,
        ventaId: ventaId,
        itemId: it.productoId,
        cantidad: it.cantidad,
        precioUsd: it.precioUsd,
        subtotalUsd: it.cantidad * it.precioUsd,
      ));
      unidadesVendidas[it.productoId] = (unidadesVendidas[it.productoId] ?? 0) + it.cantidad;
    }

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
    }

    final auditLog = AuditLog(
      timestampIso8601: DateTime.now(),
      usuario: _currentUsuarioEmail ?? '',
      hoja: 'ventas',
      celda: 'A${_ventas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '${venta.id} por USD ${venta.totalPagarUsd.toStringAsFixed(2)} (${items.length} ítems)',
      accion: 'creacion_venta_atomica',
      normaAplicada: 'ISO 8000 §5.3 / ACID',
      observaciones: 'Factura registrada en lote atómico a cliente $clienteId',
      organizacionId: _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );

    final transaction = SheetsBatchExecutor.buildVentaBatch(
      venta: venta,
      items: nuevosItems,
      unidadesVendidas: unidadesVendidas,
      deudaAgregadaCliente: deudaUsd,
      abonoInicial: abonoInicial,
      auditLog: auditLog,
    );

    // 1. Ejecutar contra Apps Script
    final res = await executeBatchTransaction(transaction);
    if (!res.isSuccess) {
      Logger.error('SheetsDataService: Falló lote atómico de venta (${res.transactionId}): ${res.message}');
      await _lanzarErrorDeLote(res, 'registrar la venta', 'revisá Ventas antes de reintentar');
    }

    // 2. ÉXITO: Asentar de forma atómica en memoria local en un solo ciclo
    final idVentaServidor = res.generatedIds['ventas'] as String? ?? ventaId;
    final ventaFinal = idVentaServidor != ventaId
        ? Venta(
            id: idVentaServidor,
            fecha: venta.fecha,
            clienteId: venta.clienteId,
            tasaBcv: venta.tasaBcv,
            tasaUsd: venta.tasaUsd,
            metodoPagoId: venta.metodoPagoId,
            comisionPagoMovilBs: venta.comisionPagoMovilBs,
            montoBs: venta.montoBs,
            montoUsd: venta.montoUsd,
            abonoUsd: venta.abonoUsd,
            deudaUsd: venta.deudaUsd,
            totalPagarUsd: venta.totalPagarUsd,
            validacion: venta.validacion,
            estado: venta.estado,
            organizacionId: venta.organizacionId,
          )
        : venta;

    _ventas.insert(0, ventaFinal);

    for (final it in nuevosItems) {
      final viFinal = idVentaServidor != ventaId
          ? VentaItem(
              id: it.id,
              ventaId: idVentaServidor,
              itemId: it.itemId,
              cantidad: it.cantidad,
              precioUsd: it.precioUsd,
              subtotalUsd: it.subtotalUsd,
            )
          : it;
      _ventaItems.insert(0, viFinal);
    }
    // El lote ya descontó el stock y sumó la deuda en Sheets: acá solo se
    // refleja localmente, con el valor que quedó en el servidor.
    unidadesVendidas.forEach((productoId, unidades) {
      final pIdx = _productos.indexWhere((p) => p.id == productoId);
      if (pIdx == -1) return;
      final p = _productos[pIdx];
      final enServidor = res.valorIncrementado('inventario', productoId)?.toInt();
      _productos[pIdx] = p.copyWith(cantidad: enServidor ?? (p.cantidad - unidades).clamp(0, 999999));
    });

    if (deudaUsd > 0) {
      final cIdx = _clientes.indexWhere((c) => c.id == clienteId);
      if (cIdx != -1) {
        final c = _clientes[cIdx];
        final enServidor = res.valorIncrementado('clientes', clienteId)?.toDouble();
        _clientes[cIdx] = c.copyWith(saldoDeudaUsd: enServidor ?? c.saldoDeudaUsd + deudaUsd);
      }
    }

    if (abonoInicial != null) {
      final abonoFinal = idVentaServidor != ventaId
          ? Abono(
              id: abonoInicial.id,
              ventaId: idVentaServidor,
              fecha: abonoInicial.fecha,
              monto: abonoInicial.monto,
              metodoPagoId: abonoInicial.metodoPagoId,
              tasaId: abonoInicial.tasaId,
            )
          : abonoInicial;
      _abonos.insert(0, abonoFinal);
    }

    _auditLogs.insert(0, auditLog);

    notifyListeners();
  }

  /// Lanza el [StateError] de un lote fallido. Si no hubo respuesta (no se
  /// sabe si se aplicó), primero relee Sheets para mostrar lo que quedó.
  Future<Never> _lanzarErrorDeLote(BatchTransactionResult res, String operacion, String sugerencia) async {
    final hayUrl = (appsScriptUrl ?? '').trim().isNotEmpty;
    if (res.sinRespuesta && hayUrl) {
      await fetchAllSheets(silent: true);
      throw StateError('No se pudo confirmar si se pudo $operacion. Se recargaron los datos: $sugerencia.');
    }
    throw StateError('No se pudo $operacion en Google Sheets${res.message != null ? ': ${res.message}' : ''}.');
  }

  /// Registra un abono (pago parcial) a una factura: crea una fila propia en
  /// el historial de abonos con su método de pago, y actualiza el total
  /// abonado/deuda/estado del header. El `metodoPago` de la factura (el de
  /// la venta original) no se toca — el método de cada pago individual vive
  /// en su propia fila de [abonos], no se pisa el de la venta.
  ///
  /// El cambio se aplica en local de inmediato y se envía como lote atómico.
  /// Si el lote falla, el cambio local se revierte: de lo contrario, al
  /// reintentar, el abono se sumaría dos veces a la cabecera de la venta.
  /// Si no hubo respuesta del servidor (no se sabe si se aplicó), además se
  /// releen los datos de Sheets para mostrar lo que realmente quedó guardado.
  Future<ResultadoAbono> registrarAbono(
    String ventaId,
    double montoAbono, {
    required String metodoPagoId,
    bool usarTasaManual = false,
  }) async {
    final index = _ventas.indexWhere((v) => v.id == ventaId);
    if (index == -1) return ResultadoAbono.rechazado;

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

    // Reducir la deuda del cliente solo en lo que el abono cubre de esta
    // factura (el excedente es saldo a favor, no reduce otra deuda).
    final deudaCubierta = montoAbono.clamp(0.0, old.deudaUsd).toDouble();
    final cIdx = _clientes.indexWhere((c) => c.id == old.clienteId);
    final clienteAntes = cIdx != -1 ? _clientes[cIdx] : null;
    if (clienteAntes != null) {
      _clientes[cIdx] = clienteAntes.copyWith(
          saldoDeudaUsd: (clienteAntes.saldoDeudaUsd - deudaCubierta).clamp(0.0, double.infinity));
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

    ClientCredit? nuevoCredito;
    if (nuevoAbono > old.totalPagarUsd) {
      final excedenteMonto = nuevoAbono - old.totalPagarUsd;
      // ID provisorio: el real lo genera el servidor (R1 del estándar).
      nuevoCredito = ClientCredit(
        id: CreditId('cr00000000'),
        clienteId: old.clienteId,
        fecha: DateTime.now(),
        montoUsd: CreditAmount(excedenteMonto),
        origenVentaId: ventaId,
        estado: CreditStatus.disponible,
        organizacionId: old.organizacionId,
        saldoUsd: excedenteMonto,
        usuarioEmail: _currentUsuarioEmail,
      );
    }

    final batchOps = <BatchOperation>[
      BatchOperation.update(
        sheet: 'ventas',
        id: ventaId,
        data: _ventas[index].toMap(),
      ),
      BatchOperation.create(
        sheet: 'abonos',
        data: Map.of(abono.toMap())..remove('id'),
      ),
      if (clienteAntes != null && deudaCubierta > 0)
        BatchOperation.increment(
          sheet: 'clientes',
          id: clienteAntes.id,
          field: 'saldo_deuda_usd',
          delta: -deudaCubierta,
          min: 0,
        ),
    ];

    if (nuevoCredito != null) {
      batchOps.add(
        BatchOperation.create(
          sheet: 'creditos_clientes',
          data: Map.of(ClientCreditModel.toMap(nuevoCredito))..remove('id'),
        ),
      );
    }

    final tx = BatchTransaction(
      transactionId: 'tx_abono_${DateTime.now().millisecondsSinceEpoch}',
      operations: batchOps,
    );

    notifyListeners();
    final txResult = await executeBatchTransaction(tx);
    if (txResult.isSuccess) {
      final idAbono = txResult.generatedIds['abonos'] as String?;
      if (idAbono != null) {
        final iAbono = _abonos.indexWhere((a) => identical(a, abono));
        if (iAbono != -1) _abonos[iAbono] = abono.copyWith(id: idAbono);
      }
      final credito = nuevoCredito;
      final idCredito = txResult.generatedIds['creditos_clientes'] as String?;
      if (credito != null) {
        addCreditoClienteLocal(idCredito != null ? credito.copyWith(id: CreditId(idCredito)) : credito);
      }
      if (clienteAntes != null) {
        final enServidor = txResult.valorIncrementado('clientes', clienteAntes.id)?.toDouble();
        final iCliente = _clientes.indexWhere((c) => c.id == clienteAntes.id);
        if (enServidor != null && iCliente != -1) {
          _clientes[iCliente] = _clientes[iCliente].copyWith(saldoDeudaUsd: enServidor);
        }
      }
      notifyListeners();
      return ResultadoAbono.registrado;
    }

    // Revertir el cambio local. Se busca por ID (no por índice): la lista
    // pudo cambiar mientras se esperaba al servidor.
    Logger.warning('SheetsDataService: abono a $ventaId no confirmado (${txResult.message}); se revierte el cambio local.');
    final iVenta = _ventas.indexWhere((v) => v.id == ventaId);
    if (iVenta != -1) _ventas[iVenta] = old;
    _abonos.removeWhere((a) => a.id == abono.id);
    if (clienteAntes != null) {
      final iCliente = _clientes.indexWhere((c) => c.id == clienteAntes.id);
      if (iCliente != -1) _clientes[iCliente] = clienteAntes;
    }
    _logAudit(
      hoja: 'ventas',
      celda: 'J${index + 2}',
      valorAnterior: 'Abono +$montoAbono ($nombreMetodo)',
      valorNuevo: 'Deuda: ${old.deudaUsd}',
      accion: 'registro_abono_revertido',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Abono a venta $ventaId no confirmado por el servidor: ${txResult.message}',
    );
    notifyListeners();

    final hayUrl = (appsScriptUrl ?? '').trim().isNotEmpty;
    if (txResult.sinRespuesta && hayUrl) {
      // Pudo haberse aplicado igual: se toma lo que diga Sheets.
      await fetchAllSheets(silent: true);
      return ResultadoAbono.sinConfirmar;
    }
    return ResultadoAbono.rechazado;
  }

  /// Anula una factura completa: elimina la venta (header), todos sus ítems,
  /// y repone el stock que esos ítems habían descontado (espejo de [addVenta]).
  Future<void> deleteVenta(String id) async {
    final index = _ventas.indexWhere((v) => v.id == id);
    if (index == -1) throw ArgumentError('No se encontró la venta $id.');
    final old = _ventas[index];
    final items = _ventaItems.where((vi) => vi.ventaId == id).toList();
    final abonosVenta = _abonos.where((a) => a.ventaId == id).toList();

    // Unidades a reponer, agrupadas por producto (solo los que siguen existiendo).
    final stockRepuesto = <String, int>{};
    for (final vi in items) {
      if (!_productos.any((p) => p.id == vi.itemId)) continue;
      stockRepuesto[vi.itemId] = (stockRepuesto[vi.itemId] ?? 0) + vi.cantidad;
    }
    final deudaAQuitar = old.deudaUsd > 0 && _clientes.any((c) => c.id == old.clienteId) ? old.deudaUsd : 0.0;

    // Un solo lote atómico: o se anula todo en Sheets o nada.
    final res = await executeBatchTransaction(BatchTransaction(
      transactionId: 'tx_anular_${id}_${DateTime.now().millisecondsSinceEpoch}',
      operations: [
        for (final a in abonosVenta) BatchOperation.delete(sheet: 'abonos', id: a.id),
        for (final vi in items) BatchOperation.delete(sheet: 'venta_items', id: vi.id),
        BatchOperation.delete(sheet: 'ventas', id: id),
        for (final e in stockRepuesto.entries)
          BatchOperation.increment(sheet: 'inventario', id: e.key, field: 'cantidad', delta: e.value),
        if (deudaAQuitar > 0)
          BatchOperation.increment(
              sheet: 'clientes', id: old.clienteId, field: 'saldo_deuda_usd', delta: -deudaAQuitar, min: 0),
      ],
    ));
    if (!res.isSuccess) {
      await _lanzarErrorDeLote(res, 'anular la venta', 'revisá si la factura sigue en Ventas');
    }

    _ventas.removeWhere((v) => v.id == id);
    _ventaItems.removeWhere((vi) => vi.ventaId == id);
    _abonos.removeWhere((a) => a.ventaId == id);
    stockRepuesto.forEach((productoId, unidades) {
      final pIdx = _productos.indexWhere((p) => p.id == productoId);
      if (pIdx == -1) return;
      final p = _productos[pIdx];
      final enServidor = res.valorIncrementado('inventario', productoId)?.toInt();
      _productos[pIdx] = p.copyWith(cantidad: enServidor ?? p.cantidad + unidades);
    });
    if (deudaAQuitar > 0) {
      final cIdx = _clientes.indexWhere((c) => c.id == old.clienteId);
      if (cIdx != -1) {
        final c = _clientes[cIdx];
        final enServidor = res.valorIncrementado('clientes', c.id)?.toDouble();
        _clientes[cIdx] =
            c.copyWith(saldoDeudaUsd: enServidor ?? (c.saldoDeudaUsd - deudaAQuitar).clamp(0.0, double.infinity));
      }
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

  /// Registra la compra en la organización actual (ID del servidor). Lanza
  /// [StateError] (sin dejar nada) si Sheets no la confirma.
  Future<void> addCompraDivisa(CompraDivisa compra) async {
    final stamped = compra.copyWith(organizacionId: _orgActualOrDefault);
    _comprasDivisas.insert(0, stamped);
    notifyListeners();
    final idReal = await _crearConRollback(
      'compras_divisas',
      Map.of(stamped.toMap())..remove('id'),
      revertir: () => _comprasDivisas.remove(stamped),
    );
    final idx = _comprasDivisas.indexOf(stamped);
    if (idx != -1) _comprasDivisas[idx] = stamped.copyWith(id: idReal);
    _logAudit(
      hoja: 'compras_divisas',
      celda: 'A${_comprasDivisas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$idReal: USD ${stamped.capitalUsd}',
      accion: 'registro_compra_divisa',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Compra cambiaria en ${stamped.plataforma} por ${stamped.vendedor}',
    );
    notifyListeners();
  }

  /// Edita la compra conservando ID, organización y validación.
  Future<void> updateCompraDivisa(CompraDivisa compra) async {
    final index = _comprasDivisas.indexWhere((c) => c.id == compra.id);
    if (index == -1) throw ArgumentError('No se encontró la compra ${compra.id}.');
    final old = _comprasDivisas[index];
    final actualizada = compra.copyWith(organizacionId: old.organizacionId, validacion: old.validacion);
    _comprasDivisas[index] = actualizada;
    _logAudit(
      hoja: 'compras_divisas',
      celda: 'A${index + 2}',
      valorAnterior: 'Capital: ${old.capitalUsd} | Com: ${old.comisionBinanceUsd}',
      valorNuevo: 'Capital: ${actualizada.capitalUsd} | Com: ${actualizada.comisionBinanceUsd}',
      accion: 'actualizacion_compra_divisa',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Modificación en orden cambiaria ${actualizada.id}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'compras_divisas', 'id': actualizada.id, 'data': actualizada.toMap()},
      revertir: () {
        final i = _comprasDivisas.indexOf(actualizada);
        if (i != -1) _comprasDivisas[i] = old;
      },
    );
  }

  Future<void> deleteCompraDivisa(String id) async {
    final index = _comprasDivisas.indexWhere((c) => c.id == id);
    if (index == -1) throw ArgumentError('No se encontró la compra $id.');
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
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'compras_divisas', 'id': id},
      revertir: () => _comprasDivisas.insert(index.clamp(0, _comprasDivisas.length), old),
    );
  }

  // ===========================================================================
  // CRUD 5: RESUMEN DIARIO (hoja resumen_diario)
  // ===========================================================================

  /// Un cierre se identifica por fecha (sin hora) + organización.
  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  int _indiceResumen(DateTime fecha, String organizacionId) {
    final dia = _soloFecha(fecha);
    return _resumenesDiarios.indexWhere(
        (r) => _soloFecha(r.fecha) == dia && r.organizacionId == organizacionId);
  }

  String get _orgActualOrDefault =>
      _currentOrganizacionId ?? '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

  /// Registra el cierre del día para la organización actual. Falla si ya
  /// existe uno para esa fecha (no lo sobrescribe en silencio). El ID
  /// (rd00000001…) lo asigna el servidor.
  Future<void> addResumenDiario(ResumenDiario resumen) async {
    final stamped = resumen.copyWith(
      id: '',
      fecha: _soloFecha(resumen.fecha),
      organizacionId: _orgActualOrDefault,
    );
    final fechaTxt = stamped.fechaIso;
    if (_indiceResumen(stamped.fecha, stamped.organizacionId) != -1) {
      throw ArgumentError('Ya existe un cierre para $fechaTxt. Editalo en lugar de crear otro.');
    }
    _resumenesDiarios.insert(0, stamped);
    notifyListeners();

    final idReal = await _crearConRollback(
      'resumen_diario',
      stamped.toMap(),
      revertir: () => _resumenesDiarios.remove(stamped),
    );
    final i = _resumenesDiarios.indexOf(stamped);
    final confirmado = stamped.copyWith(id: idReal);
    if (i != -1) _resumenesDiarios[i] = confirmado;
    _logAudit(
      hoja: 'resumen_diario',
      celda: 'A${_resumenesDiarios.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$idReal ($fechaTxt): USD ${confirmado.totalUsd}',
      accion: 'cierre_diario',
      norma: 'COBIT 2019 / ISO 27001',
      observaciones: 'Registro de balance diario para $fechaTxt',
    );
    notifyListeners();
  }

  int _indiceResumenPorId(String id) =>
      id.isEmpty ? -1 : _resumenesDiarios.indexWhere((r) => r.id == id);

  /// Actualiza los montos del cierre [resumen].id. La fecha y la
  /// organización no cambian.
  Future<void> updateResumenDiario(ResumenDiario resumen) async {
    final index = _indiceResumenPorId(resumen.id);
    if (index == -1) {
      throw ArgumentError('No se encontró el cierre. Actualizá la lista e intentá de nuevo.');
    }
    final anterior = _resumenesDiarios[index];
    final actualizado = resumen.copyWith(
      fecha: anterior.fecha,
      organizacionId: anterior.organizacionId,
    );
    _resumenesDiarios[index] = actualizado;
    _logAudit(
      hoja: 'resumen_diario',
      celda: 'A${index + 2}',
      valorAnterior: '${anterior.id}: USD ${anterior.totalUsd}, Bs ${anterior.totalBs}',
      valorNuevo: '${actualizado.id}: USD ${actualizado.totalUsd}, Bs ${actualizado.totalBs}',
      accion: 'actualizacion_resumen_diario',
      norma: 'COBIT 2019',
      observaciones: 'Ajuste manual al cierre ${actualizado.id} (${actualizado.fechaIso})',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'resumen_diario', 'id': actualizado.id, 'data': actualizado.toMap()},
      revertir: () {
        final i = _resumenesDiarios.indexOf(actualizado);
        if (i != -1) _resumenesDiarios[i] = anterior;
      },
    );
  }

  Future<void> deleteResumenDiario(String id) async {
    final index = _indiceResumenPorId(id);
    if (index == -1) {
      throw ArgumentError('No se encontró el cierre a eliminar.');
    }
    final eliminado = _resumenesDiarios.removeAt(index);
    _logAudit(
      hoja: 'resumen_diario',
      celda: 'A${index + 2}',
      valorAnterior: '${eliminado.id} (${eliminado.fechaIso})',
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_resumen_diario',
      norma: 'COBIT 2019',
      observaciones: 'Eliminado cierre ${eliminado.id} de fecha ${eliminado.fechaIso}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {
        'action': 'delete',
        'sheet': 'resumen_diario',
        'id': eliminado.id,
        'data': {'organizacion_id': eliminado.organizacionId},
      },
      revertir: () => _resumenesDiarios.insert(index.clamp(0, _resumenesDiarios.length), eliminado),
    );
  }

  // ===========================================================================
  // CRUD 6: CUARENTENA (hoja cuarentena)
  // ===========================================================================

  int _indicePorId<T>(List<T> lista, String id, String Function(T) idDe) =>
      id.isEmpty ? -1 : lista.indexWhere((e) => idDe(e) == id);

  /// Error si [organizacionId] no es la organización actual (R6).
  void _verificarOrganizacionActual(String organizacionId) {
    if (organizacionId != _orgActualOrDefault) {
      throw ArgumentError('El registro no pertenece a esta organización.');
    }
  }

  Future<void> addCuarentena(RegistroCuarentena item) async {
    final errores = item.errores;
    if (errores.isNotEmpty) throw ArgumentError(errores.values.first);
    final stamped = item.copyWith(id: '', organizacionId: _orgActualOrDefault);
    _cuarentenas.insert(0, stamped);
    notifyListeners();
    final id = await _crearConRollback(
      'cuarentena',
      stamped.toMap(),
      revertir: () => _cuarentenas.remove(stamped),
    );
    final i = _cuarentenas.indexOf(stamped);
    if (i != -1) _cuarentenas[i] = stamped.copyWith(id: id);
    _logAudit(
      hoja: 'cuarentena',
      celda: 'A${_cuarentenas.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$id: ${stamped.idRegistroOriginal} (${stamped.motivoCuarentena})',
      accion: 'ingreso_cuarentena',
      norma: 'COBIT 2019 DSS05',
      observaciones: 'Anomalía aislada desde hoja ${stamped.hojaOrigen}',
    );
    notifyListeners();
  }

  /// Actualiza estado y resolución del registro [item].id.
  Future<void> updateCuarentena(RegistroCuarentena item) async {
    // Al resolver solo cambian estado y resolución: no se revalidan los datos
    // originales (registros viejos pueden tener un JSON mal formado).
    final errorEstado = item.errores['estado'];
    if (errorEstado != null) throw ArgumentError(errorEstado);
    final index = _indicePorId(_cuarentenas, item.id, (c) => c.id);
    if (index == -1) throw ArgumentError('No se encontró el registro en cuarentena.');
    final anterior = _cuarentenas[index];
    _verificarOrganizacionActual(anterior.organizacionId);
    final actualizado = anterior.copyWith(estado: item.estado, resolucion: item.resolucion);
    _cuarentenas[index] = actualizado;
    _logAudit(
      hoja: 'cuarentena',
      celda: 'G${index + 2}',
      valorAnterior: '${anterior.estado}: ${anterior.resolucion}',
      valorNuevo: '${actualizado.estado}: ${actualizado.resolucion}',
      accion: 'resolucion_cuarentena',
      norma: 'COBIT 2019 DSS05',
      observaciones: 'Actualizada resolución del registro ${actualizado.id}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'cuarentena', 'id': actualizado.id, 'data': actualizado.toMap()},
      revertir: () {
        final i = _cuarentenas.indexOf(actualizado);
        if (i != -1) _cuarentenas[i] = anterior;
      },
    );
  }

  Future<void> deleteCuarentena(String id) async {
    final index = _indicePorId(_cuarentenas, id, (c) => c.id);
    if (index == -1) throw ArgumentError('No se encontró el registro en cuarentena.');
    final eliminado = _cuarentenas[index];
    _verificarOrganizacionActual(eliminado.organizacionId);
    _cuarentenas.removeAt(index);
    _logAudit(
      hoja: 'cuarentena',
      celda: 'A${index + 2}',
      valorAnterior: 'Registro ${eliminado.id}',
      valorNuevo: 'PURGADO',
      accion: 'descarte_cuarentena',
      norma: 'COBIT 2019 DSS05',
      observaciones: 'Registro purgado de cuarentena',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'cuarentena', 'id': id, 'data': {'organizacion_id': eliminado.organizacionId}},
      revertir: () => _cuarentenas.insert(index.clamp(0, _cuarentenas.length), eliminado),
    );
  }

  // ===========================================================================
  // CRUD 7: AUDIT LOG (hoja audit_log) — inmutable: solo altas
  // ===========================================================================

  /// Registra una entrada manual en la bitácora. La bitácora no se edita ni
  /// se borra (ISO/IEC 27001 §8.15): el script lo rechaza.
  Future<void> addAuditLogManual(AuditLog log) async {
    final usuario = _currentUsuarioEmail;
    if (usuario == null) {
      throw StateError('No hay un usuario identificado para firmar la entrada.');
    }
    final stamped = AuditLog(
      timestampIso8601: log.timestampIso8601,
      usuario: usuario,
      hoja: log.hoja,
      celda: log.celda,
      valorAnterior: log.valorAnterior,
      valorNuevo: log.valorNuevo,
      accion: log.accion,
      normaAplicada: log.normaAplicada,
      observaciones: log.observaciones,
      organizacionId: _orgActualOrDefault,
    );
    _auditLogs.insert(0, stamped);
    notifyListeners();
    final id = await _crearConRollback(
      'audit_log',
      stamped.toMap(),
      revertir: () => _auditLogs.remove(stamped),
    );
    final i = _auditLogs.indexOf(stamped);
    if (i != -1) {
      _auditLogs[i] = AuditLog(
        id: id,
        timestampIso8601: stamped.timestampIso8601,
        usuario: stamped.usuario,
        hoja: stamped.hoja,
        celda: stamped.celda,
        valorAnterior: stamped.valorAnterior,
        valorNuevo: stamped.valorNuevo,
        accion: stamped.accion,
        normaAplicada: stamped.normaAplicada,
        observaciones: stamped.observaciones,
        organizacionId: stamped.organizacionId,
      );
    }
    notifyListeners();
  }

  // ===========================================================================
  // CRUD 8: REPORTE MIGRACIÓN (hoja reporte_migracion)
  // ===========================================================================

  Future<void> addReporteMigracion(ReporteMigracion rep) async {
    final errores = rep.errores;
    if (errores.isNotEmpty) throw ArgumentError(errores.values.first);
    final stamped = rep.copyWith(id: '', organizacionId: _orgActualOrDefault);
    _reportesMigracion.add(stamped);
    notifyListeners();
    final id = await _crearConRollback(
      'reporte_migracion',
      stamped.toMap(),
      revertir: () => _reportesMigracion.remove(stamped),
    );
    final i = _reportesMigracion.indexOf(stamped);
    if (i != -1) _reportesMigracion[i] = stamped.copyWith(id: id);
    _logAudit(
      hoja: 'reporte_migracion',
      celda: 'A${_reportesMigracion.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$id ${stamped.metrica}: ${stamped.valorEstado}',
      accion: 'alta_control_migracion',
      norma: stamped.normaAplicada,
      observaciones: stamped.observaciones,
    );
    notifyListeners();
  }

  Future<void> updateReporteMigracion(ReporteMigracion rep) async {
    final errores = rep.errores;
    if (errores.isNotEmpty) throw ArgumentError(errores.values.first);
    final index = _indicePorId(_reportesMigracion, rep.id, (r) => r.id);
    if (index == -1) throw ArgumentError('No se encontró el control de migración.');
    final anterior = _reportesMigracion[index];
    _verificarOrganizacionActual(anterior.organizacionId);
    final actualizado = rep.copyWith(organizacionId: anterior.organizacionId);
    _reportesMigracion[index] = actualizado;
    _logAudit(
      hoja: 'reporte_migracion',
      celda: 'C${index + 2}',
      valorAnterior: anterior.valorEstado,
      valorNuevo: actualizado.valorEstado,
      accion: 'actualizacion_control_migracion',
      norma: actualizado.normaAplicada,
      observaciones: 'Ajuste en ${actualizado.metrica}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'reporte_migracion', 'id': actualizado.id, 'data': actualizado.toMap()},
      revertir: () {
        final i = _reportesMigracion.indexOf(actualizado);
        if (i != -1) _reportesMigracion[i] = anterior;
      },
    );
  }

  Future<void> deleteReporteMigracion(String id) async {
    final index = _indicePorId(_reportesMigracion, id, (r) => r.id);
    if (index == -1) throw ArgumentError('No se encontró el control de migración.');
    final eliminado = _reportesMigracion[index];
    _verificarOrganizacionActual(eliminado.organizacionId);
    _reportesMigracion.removeAt(index);
    _logAudit(
      hoja: 'reporte_migracion',
      celda: 'A${index + 2}',
      valorAnterior: eliminado.metrica,
      valorNuevo: 'ELIMINADO',
      accion: 'baja_control_migracion',
      norma: eliminado.normaAplicada,
      observaciones: 'Control retirado del cuadro de mando',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'reporte_migracion', 'id': id, 'data': {'organizacion_id': eliminado.organizacionId}},
      revertir: () => _reportesMigracion.insert(index.clamp(0, _reportesMigracion.length), eliminado),
    );
  }

  // ===========================================================================
  // CRUD 9: CHECKLIST ISO (hoja checklist_iso)
  // ===========================================================================

  /// Siguiente nro de control (máximo + 1 entre todas las organizaciones,
  /// igual que el servidor, que es quien lo asigna en definitiva).
  int get nextChecklistNro =>
      _checklistIsos.fold<int>(0, (m, c) => c.nro > m ? c.nro : m) + 1;

  Future<void> addChecklistIso(ChecklistISO check) async {
    final errores = check.errores;
    if (errores.isNotEmpty) throw ArgumentError(errores.values.first);
    final stamped = check.copyWith(id: '', nro: nextChecklistNro, organizacionId: _orgActualOrDefault);
    _checklistIsos.add(stamped);
    notifyListeners();
    final id = await _crearConRollback(
      'checklist_iso',
      stamped.toMap(),
      revertir: () => _checklistIsos.remove(stamped),
    );
    final i = _checklistIsos.indexOf(stamped);
    if (i != -1) _checklistIsos[i] = stamped.copyWith(id: id);
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'A${_checklistIsos.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$id ${stamped.control} (${stamped.norma})',
      accion: 'alta_requisito_iso',
      norma: stamped.norma,
      observaciones: stamped.evidencia,
    );
    notifyListeners();
  }

  Future<void> toggleChecklistEstado(String id) async {
    final index = _indicePorId(_checklistIsos, id, (c) => c.id);
    if (index == -1) throw ArgumentError('No se encontró el control.');
    final anterior = _checklistIsos[index];
    _verificarOrganizacionActual(anterior.organizacionId);
    final nuevoEstado = anterior.estado == '☑' ? '☐' : '☑';
    final actualizado = anterior.copyWith(estado: nuevoEstado, timestamp: DateTime.now());
    _checklistIsos[index] = actualizado;
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'E${index + 2}',
      valorAnterior: anterior.estado,
      valorNuevo: nuevoEstado,
      accion: 'cambio_estado_conformidad',
      norma: anterior.norma,
      observaciones: 'Control #${anterior.nro} marcado como $nuevoEstado',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'toggle_checklist', 'sheet': 'checklist_iso', 'id': id, 'estado': nuevoEstado},
      revertir: () {
        final i = _checklistIsos.indexOf(actualizado);
        if (i != -1) _checklistIsos[i] = anterior;
      },
    );
  }

  /// Actualiza control, norma, evidencia y estado. La fecha de verificación
  /// solo cambia si cambia el estado (antes se ponía "ahora" siempre).
  Future<void> updateChecklistIso(ChecklistISO check) async {
    final errores = check.errores;
    if (errores.isNotEmpty) throw ArgumentError(errores.values.first);
    final index = _indicePorId(_checklistIsos, check.id, (c) => c.id);
    if (index == -1) throw ArgumentError('No se encontró el control.');
    final anterior = _checklistIsos[index];
    _verificarOrganizacionActual(anterior.organizacionId);
    final actualizado = anterior.copyWith(
      control: check.control,
      norma: check.norma,
      evidencia: check.evidencia,
      estado: check.estado,
      timestamp: check.estado != anterior.estado ? DateTime.now() : anterior.timestamp,
    );
    _checklistIsos[index] = actualizado;
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'C${index + 2}',
      valorAnterior: 'Control #${anterior.nro}',
      valorNuevo: '${actualizado.control} (${actualizado.estado})',
      accion: 'actualizacion_checklist',
      norma: actualizado.norma,
      observaciones: 'Control #${actualizado.nro} actualizado',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'checklist_iso', 'id': actualizado.id, 'data': actualizado.toMap()},
      revertir: () {
        final i = _checklistIsos.indexOf(actualizado);
        if (i != -1) _checklistIsos[i] = anterior;
      },
    );
  }

  Future<void> deleteChecklistIso(String id) async {
    final index = _indicePorId(_checklistIsos, id, (c) => c.id);
    if (index == -1) throw ArgumentError('No se encontró el control.');
    final eliminado = _checklistIsos[index];
    _verificarOrganizacionActual(eliminado.organizacionId);
    _checklistIsos.removeAt(index);
    _logAudit(
      hoja: 'checklist_iso',
      celda: 'A${index + 2}',
      valorAnterior: 'Control #${eliminado.nro}: ${eliminado.control}',
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_checklist',
      norma: eliminado.norma,
      observaciones: 'Requisito retirado del checklist',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'checklist_iso', 'id': id, 'data': {'organizacion_id': eliminado.organizacionId}},
      revertir: () => _checklistIsos.insert(index.clamp(0, _checklistIsos.length), eliminado),
    );
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
      Cliente(
        id: 'c00000002',
        nombre: 'Neyza Chourio',
        telefono: '+584120000002',
        email: 'neyza.chourio@ejemplo.com',
        saldoDeudaUsd: 100.0,
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
        fotoId: 'g00000001',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _galeria = [
      GaleriaItem(
        id: 'g00000001',
        url: 'https://lh3.googleusercontent.com/d/1_DRIVE_FILE_ID_PANTALON_CASUAL',
        driveFileId: '1_DRIVE_FILE_ID_PANTALON_CASUAL',
        nombreArchivo: 'pantalon_casual.jpg',
        fechaSubida: DateTime(2026, 4, 3),
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
      Venta(
        id: 'v00000002',
        fecha: DateTime(2026, 4, 2),
        clienteId: 'c00000002',
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        metodoPagoId: 'mp00000001',
        comisionPagoMovilBs: 0.0,
        montoBs: 85320.0,
        montoUsd: 180.0,
        abonoUsd: 180.0,
        deudaUsd: 0.0,
        totalPagarUsd: 180.0,
        validacion: 'OK',
        estado: EstadoVenta.pagada,
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      Venta(
        id: 'v00000005',
        fecha: DateTime(2026, 4, 4),
        clienteId: 'c00000002',
        tasaBcv: 474.0,
        tasaUsd: 30.0,
        metodoPagoId: 'mp00000001',
        comisionPagoMovilBs: 0.0,
        montoBs: 47400.0,
        montoUsd: 100.0,
        abonoUsd: 0.0,
        deudaUsd: 100.0,
        totalPagarUsd: 100.0,
        validacion: 'OK',
        estado: EstadoVenta.pendiente,
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
        id: 'rd00000001',
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
        id: 'cq00000001',
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
        id: 'cq00000002',
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
        id: 'al00000001',
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
        id: 'al00000002',
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
        id: 'rm00000001',
metrica: 'Integridad Referencial (FKs)',
        valorEstado: '100% Conforme',
        normaAplicada: 'ISO 8000 §4.2',
        observaciones: '0 referencias huérfanas en clientes e inventario',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const ReporteMigracion(
        id: 'rm00000002',
metrica: 'Cumplimiento Formatos Internacionales',
        valorEstado: 'E.164 y ISO 8601',
        normaAplicada: 'RFC 4180 / ISO 8601',
        observaciones: 'Fechas estandarizadas en YYYY-MM-DD y teléfonos con prefijo de país',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const ReporteMigracion(
        id: 'rm00000003',
metrica: 'Seguridad y Cero Polling',
        valorEstado: 'Activo',
        normaAplicada: 'ISO/IEC 25010 / ISO 27001',
        observaciones: 'Actualizaciones bajo demanda manual sin temporizadores periódicos',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
    ];

    _checklistIsos = [
      ChecklistISO(
        id: 'ck00000001',
nro: 1,
        control: 'Backup verificado en 3 formatos (XLSX, CSV, JSON)',
        norma: 'ISO/IEC 27001 §8.13',
        estado: '☑',
        evidencia: 'Backups/2026/Estilo Neutral_BACKUP_FASE10',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        id: 'ck00000002',
nro: 2,
        control: 'Hash SHA-256 original registrado en bitácora',
        norma: 'NIST SP 800-53',
        estado: '☑',
        evidencia: 'audit_log!E2',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        id: 'ck00000003',
nro: 3,
        control: '0 encabezados duplicados en 9 hojas',
        norma: 'ISO 8000 §4.1',
        estado: '☑',
        evidencia: 'Hojas: clientes, inventario, ventas, compras_divisas, etc.',
        timestamp: DateTime.parse('2026-09-14T09:09:53.194152-04:00'),
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      ChecklistISO(
        id: 'ck00000004',
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
        id: 'sg00000001',
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
        id: 'uo00000001',
usuarioEmail: 'neidapulgar1989@gmail.com',
        organizacionId: '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      ),
      const UsuarioOrganizacion(
        id: 'uo00000002',
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
      const MetodoPago(id: 'mp00000009', nombre: 'Saldo a Favor', status: true),
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
  Future<void> setMetodoSeguridad(String? metodo) async {
    assert(
      metodo == null || _etiquetasMetodoSeguridad.containsKey(metodo),
      'Método de seguridad inválido: $metodo',
    );

    final old = seguridad;
    final nuevo = Seguridad(
      id: old.id,
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
      celda: 'B2:D2',
      valorAnterior: anterior,
      valorNuevo: actual,
      accion: 'cambio_metodo_seguridad',
      norma: 'ISO/IEC 27001 §9.4',
      observaciones: 'Método de seguridad activo cambiado de "$anterior" a "$actual"',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {
        'action': 'set_metodo_seguridad',
        'sheet': 'seguridad',
        'biometrico': nuevo.biometrico,
        'desbloqueo_facial': nuevo.desbloqueoFacial,
        'dos_factores': nuevo.dosFactores,
        'usuario_email': nuevo.usuarioEmail,
      },
      revertir: () => _replaceSeguridadForCurrentUsuario(old),
    );
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
  /// Devuelve `false` (sin dejar nada a medias) si Sheets no lo confirma.
  Future<bool> addUsuario(Usuario usuario, {required String organizacionId}) async {
    final provisional = usuario.copyWith(email: usuario.email.trim().toLowerCase());
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(provisional.email)) {
      throw ArgumentError('Correo electrónico inválido: "${provisional.email}".');
    }
    if (_usuarios.any((u) => u.email.trim().toLowerCase() == provisional.email)) {
      throw ArgumentError('El correo ${provisional.email} ya tiene acceso.');
    }
    if (!_organizaciones.any((o) => o.id == organizacionId)) {
      throw ArgumentError('La organización elegida ya no existe.');
    }
    final membresia = UsuarioOrganizacion(usuarioEmail: provisional.email, organizacionId: organizacionId);
    _usuarios.add(provisional);
    _usuarioOrganizaciones.add(membresia);
    _logAudit(
      hoja: 'usuarios',
      celda: 'A${_usuarios.length + 1}',
      valorAnterior: 'null',
      valorNuevo: provisional.email,
      accion: 'alta_usuario',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Alta de usuario autorizado, organización $organizacionId',
    );
    notifyListeners();

    void revertirTodo() {
      _usuarios.remove(provisional);
      _usuarioOrganizaciones.remove(membresia);
    }

    try {
      final datosUsuario = Map.of(provisional.toMap())..remove('id'); // lo genera el servidor
      final idUsuario = await _crearConRollback('usuarios', datosUsuario, revertir: revertirTodo);
      final String idMembresia;
      try {
        idMembresia = await _crearConRollback('usuario_organizacion', membresia.toMap(), revertir: revertirTodo);
      } on StateError {
        // Sin membresía el usuario no puede entrar: se deshace también el alta.
        try {
          await _sincronizarConRollback(
            {'action': 'delete', 'sheet': 'usuarios', 'id': idUsuario},
            revertir: () {},
          );
        } on StateError {
          Logger.error('SheetsDataService: quedó el usuario $idUsuario sin membresía en Sheets.');
        }
        return false;
      }
      final iU = _usuarios.indexOf(provisional);
      if (iU != -1) _usuarios[iU] = provisional.copyWith(id: idUsuario);
      final iM = _usuarioOrganizaciones.indexOf(membresia);
      if (iM != -1) _usuarioOrganizaciones[iM] = membresia.copyWith(id: idMembresia);
      notifyListeners();
      return true;
    } on StateError {
      return false;
    }
  }

  /// Actualiza nombre/documento y organización de un usuario. El email es
  /// inmutable (es la clave de `seguridad` y del login). Devuelve `false` si
  /// Sheets no confirma alguno de los dos cambios (el que falló se revierte).
  Future<bool> updateUsuario(Usuario usuario, {required String organizacionId}) async {
    final index = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (index == -1) return false;
    if (!_organizaciones.any((o) => o.id == organizacionId)) {
      throw ArgumentError('La organización elegida ya no existe.');
    }
    final anterior = _usuarios[index];
    // El estado solo cambia con cambiarEstadoUsuario.
    final actualizado = usuario.copyWith(email: anterior.email, activo: anterior.activo);
    _usuarios[index] = actualizado;

    final membresiaAnterior = _membresiaDe(anterior.email);
    final membresiaNueva = (membresiaAnterior ??
            UsuarioOrganizacion(usuarioEmail: anterior.email, organizacionId: organizacionId))
        .copyWith(organizacionId: organizacionId);
    if (membresiaAnterior != null) {
      _usuarioOrganizaciones[_usuarioOrganizaciones.indexOf(membresiaAnterior)] = membresiaNueva;
    } else {
      _usuarioOrganizaciones.add(membresiaNueva);
    }

    _logAudit(
      hoja: 'usuarios',
      celda: 'A${index + 2}',
      valorAnterior: '${anterior.nombre} (org ${membresiaAnterior?.organizacionId ?? '-'})',
      valorNuevo: '${actualizado.nombre} (org $organizacionId)',
      accion: 'actualizacion_usuario',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Edición de usuario vía App Móvil',
    );
    notifyListeners();

    void revertirMembresia() {
      final i = _usuarioOrganizaciones.indexOf(membresiaNueva);
      if (i == -1) return;
      if (membresiaAnterior != null) {
        _usuarioOrganizaciones[i] = membresiaAnterior;
      } else {
        _usuarioOrganizaciones.removeAt(i);
      }
    }

    try {
      await _sincronizarConRollback(
        {'action': 'update', 'sheet': 'usuarios', 'id': actualizado.id, 'data': actualizado.toMap()},
        revertir: () {
          final i = _usuarios.indexOf(actualizado);
          if (i != -1) _usuarios[i] = anterior;
          revertirMembresia();
        },
      );
      if (membresiaAnterior == null || membresiaAnterior.id.isEmpty) {
        // Sin membresía confirmada en Sheets: se crea.
        final id = await _crearConRollback('usuario_organizacion', membresiaNueva.copyWith(id: '').toMap(),
            revertir: revertirMembresia);
        final i = _usuarioOrganizaciones.indexOf(membresiaNueva);
        if (i != -1) _usuarioOrganizaciones[i] = membresiaNueva.copyWith(id: id);
        notifyListeners();
      } else if (membresiaAnterior.organizacionId != organizacionId) {
        await _sincronizarConRollback(
          {
            'action': 'update',
            'sheet': 'usuario_organizacion',
            'id': membresiaNueva.id,
            'data': membresiaNueva.toMap(),
          },
          revertir: revertirMembresia,
        );
      }
      return true;
    } on StateError {
      return false;
    }
  }

  /// Motivo por el que no se puede cambiar el estado de [usuario], o `null`.
  /// Nadie puede inactivarse a sí mismo (se quedaría afuera sin poder volver).
  String? motivoNoInactivable(Usuario usuario) {
    if (usuario.email.trim().toLowerCase() == _currentUsuarioEmail) {
      return 'No podés inactivar tu propia cuenta.';
    }
    return null;
  }

  /// Activa o inactiva un usuario sin borrarlo. Inactivo no puede iniciar
  /// sesión, y el servidor le envía un push silencioso que cierra la sesión
  /// abierta en sus teléfonos. Revierte y lanza [StateError] si Sheets no lo
  /// confirma; [ArgumentError] si es el propio usuario de la sesión.
  Future<void> cambiarEstadoUsuario(String id, {required bool activo}) async {
    final index = _usuarios.indexWhere((u) => u.id == id);
    if (index == -1) throw ArgumentError('No se encontró el usuario $id.');
    final old = _usuarios[index];
    if (old.activo == activo) return;
    if (!activo) {
      final motivo = motivoNoInactivable(old);
      if (motivo != null) throw ArgumentError(motivo);
    }
    final actualizado = old.copyWith(activo: activo);
    _usuarios[index] = actualizado;
    _logAudit(
      hoja: 'usuarios',
      celda: 'F${index + 2}',
      valorAnterior: old.activo ? 'activo' : 'inactivo',
      valorNuevo: activo ? 'activo' : 'inactivo',
      accion: activo ? 'activacion_usuario' : 'inactivacion_usuario',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Usuario ${old.email} ${activo ? 'activado' : 'inactivado'}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'usuarios', 'id': id, 'data': {'status': activo}},
      revertir: () {
        final i = _usuarios.indexOf(actualizado);
        if (i != -1) _usuarios[i] = old;
      },
    );
  }

  /// Elimina un usuario y su membresía. Su fila de `seguridad` queda (es
  /// inofensiva: sin usuario ni membresía nadie puede entrar con ese email).
  /// Devuelve `false` si Sheets no lo confirma (y se revierte).
  Future<bool> deleteUsuario(Usuario usuario) async {
    final index = _usuarios.indexWhere((u) => u.id == usuario.id);
    if (index == -1) return false;
    final eliminado = _usuarios.removeAt(index);
    final membresia = _membresiaDe(eliminado.email);
    final indexMembresia = membresia == null ? -1 : _usuarioOrganizaciones.indexOf(membresia);
    if (indexMembresia != -1) _usuarioOrganizaciones.removeAt(indexMembresia);

    _logAudit(
      hoja: 'usuarios',
      celda: 'A${index + 2}',
      valorAnterior: '${eliminado.id} (${eliminado.email})',
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_usuario',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Baja de acceso de usuario vía App Móvil',
    );
    notifyListeners();

    try {
      // Primero la membresía: sin ella el usuario ya no puede entrar.
      if (membresia != null && membresia.id.isNotEmpty) {
        await _sincronizarConRollback(
          {'action': 'delete', 'sheet': 'usuario_organizacion', 'id': membresia.id},
          revertir: () {
            _usuarios.insert(index.clamp(0, _usuarios.length), eliminado);
            _usuarioOrganizaciones.insert(indexMembresia.clamp(0, _usuarioOrganizaciones.length), membresia);
          },
        );
      }
      await _sincronizarConRollback(
        {'action': 'delete', 'sheet': 'usuarios', 'id': eliminado.id},
        // La membresía ya se borró en Sheets: localmente queda sin acceso.
        revertir: () => _usuarios.insert(index.clamp(0, _usuarios.length), eliminado),
      );
      return true;
    } on StateError {
      return false;
    }
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

  /// Crea la organización (UUID v4 generado acá: única excepción a R1).
  /// Lanza [ArgumentError] si el nombre está vacío o repetido, y
  /// [StateError] (sin dejar nada) si Sheets no la confirma.
  static String _emailOrganizacion(String email) {
    final limpio = email.trim().toLowerCase();
    if (limpio.isNotEmpty && !Organizacion.formatoEmail.hasMatch(limpio)) {
      throw ArgumentError('El correo "$limpio" no es válido.');
    }
    return limpio;
  }

  Future<void> addOrganizacion(String nombre, {String email = ''}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) throw ArgumentError('El nombre de la organización es obligatorio.');
    final correo = _emailOrganizacion(email);
    if (_organizaciones.any((o) => o.nombre.trim().toLowerCase() == limpio.toLowerCase())) {
      throw ArgumentError('Ya existe una organización llamada "$limpio".');
    }
    final nuevo = Organizacion(id: _generarOrganizacionId(), nombre: limpio, email: correo);
    _organizaciones.add(nuevo);
    notifyListeners();
    await _crearConRollback('organizaciones', nuevo.toMap(), revertir: () => _organizaciones.remove(nuevo));
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
  }

  Future<void> updateOrganizacion(Organizacion organizacion) async {
    final index = _organizaciones.indexWhere((o) => o.id == organizacion.id);
    if (index == -1) throw ArgumentError('No se encontró la organización.');
    final limpio = organizacion.nombre.trim();
    if (limpio.isEmpty) throw ArgumentError('El nombre de la organización es obligatorio.');
    if (_organizaciones.any((o) => o.id != organizacion.id && o.nombre.trim().toLowerCase() == limpio.toLowerCase())) {
      throw ArgumentError('Ya existe una organización llamada "$limpio".');
    }
    final old = _organizaciones[index];
    final actualizada = Organizacion(id: old.id, nombre: limpio, email: _emailOrganizacion(organizacion.email));
    if (actualizada.nombre == old.nombre && actualizada.email == old.email) return; // nada que guardar
    _organizaciones[index] = actualizada;
    _logAudit(
      hoja: 'organizaciones',
      celda: 'A${index + 2}',
      valorAnterior: '${old.nombre} <${old.email}>',
      valorNuevo: '${actualizada.nombre} <${actualizada.email}>',
      accion: 'actualizacion_organizacion',
      norma: 'ISO/IEC 27001 §9.2',
      observaciones: 'Edición de organización vía App Móvil',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'organizaciones', 'id': actualizada.id, 'data': actualizada.toMap()},
      revertir: () {
        final i = _organizaciones.indexOf(actualizada);
        if (i != -1) _organizaciones[i] = old;
      },
    );
  }

  /// Elimina una organización. Se rechaza si es la organización en uso o si
  /// todavía tiene usuarios (dejaría membresías huérfanas).
  /// Motivo por el que [organizacionId] no se puede eliminar, o `null`.
  /// Una organización con datos propios dejaría esas filas huérfanas (y sus
  /// tasas manuales pueden estar referenciadas por ventas y abonos).
  String? motivoNoEliminableOrganizacion(String organizacionId) {
    if (organizacionId == _currentOrganizacionId) {
      return 'Es la organización en la que estás trabajando.';
    }
    final usuarios = usuariosEnOrganizacion(organizacionId);
    if (usuarios > 0) {
      return 'Tiene $usuarios ${usuarios == 1 ? 'usuario' : 'usuarios'}. Movelos primero.';
    }
    final datos = <String>[
      for (final (n, singular, plural) in [
        (_clientes.where((c) => c.organizacionId == organizacionId).length, 'cliente', 'clientes'),
        (_productos.where((p) => p.organizacionId == organizacionId).length, 'producto', 'productos'),
        (_ventas.where((v) => v.organizacionId == organizacionId).length, 'venta', 'ventas'),
        (_comprasDivisas.where((c) => c.organizacionId == organizacionId).length, 'compra de divisas', 'compras de divisas'),
      ])
        if (n > 0) '$n ${n == 1 ? singular : plural}',
    ];
    if (datos.isNotEmpty) return 'Tiene ${datos.join(', ')}.';
    return null;
  }

  /// Elimina la organización junto con su moneda base y sus tasas manuales,
  /// en un solo lote atómico (antes quedaban filas huérfanas en
  /// `moneda_organizacion` y `tasas`). Lanza [ArgumentError] si no se puede
  /// eliminar y [StateError] si Sheets no lo confirma; los datos locales se
  /// tocan solo después de la confirmación.
  Future<void> deleteOrganizacion(String organizacionId) async {
    final motivo = motivoNoEliminableOrganizacion(organizacionId);
    if (motivo != null) throw ArgumentError('No se puede eliminar la organización. $motivo');
    final index = _organizaciones.indexWhere((o) => o.id == organizacionId);
    if (index == -1) throw ArgumentError('No se encontró la organización.');
    final old = _organizaciones[index];
    final monedas = _monedasOrganizacion.where((m) => m.organizacionId == organizacionId).toList();
    final tasasManuales =
        _tasas.where((t) => t.fuente == 'manual' && t.organizacionId == organizacionId).toList();

    final res = await executeBatchTransaction(BatchTransaction(
      transactionId: 'tx_baja_org_${DateTime.now().millisecondsSinceEpoch}',
      operations: [
        for (final m in monedas)
          if (m.id.isNotEmpty) BatchOperation.delete(sheet: 'moneda_organizacion', id: m.id),
        for (final t in tasasManuales)
          if (t.id.isNotEmpty) BatchOperation.delete(sheet: 'tasas', id: t.id),
        BatchOperation.delete(sheet: 'organizaciones', id: organizacionId),
      ],
    ));
    if (!res.isSuccess) {
      await _lanzarErrorDeLote(res, 'eliminar la organización', 'revisá si sigue en Organizaciones');
    }

    _organizaciones.removeWhere((o) => o.id == organizacionId);
    _monedasOrganizacion.removeWhere((m) => m.organizacionId == organizacionId);
    _tasas.removeWhere((t) => t.fuente == 'manual' && t.organizacionId == organizacionId);
    _logAudit(
      hoja: 'organizaciones',
      celda: 'A${index + 2}',
      valorAnterior: '${old.id} (${old.nombre})',
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_organizacion',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Baja de organización con ${monedas.length} moneda(s) y ${tasasManuales.length} tasa(s) manual(es)',
    );
    notifyListeners();
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

  /// IDs de métodos de pago usados en ventas o abonos.
  Set<String> get metodosPagoEnUso => {
        for (final v in _ventas) v.metodoPagoId,
        for (final a in _abonos) a.metodoPagoId,
      };

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
    final provisional = MetodoPago(id: '', nombre: trimmed, status: true);
    _metodosPago.add(provisional);
    notifyListeners();
    final id = await _crearConRollback(
      'metodo pago',
      Map.of(provisional.toMap())..remove('id'), // el ID lo genera el servidor
      revertir: () => _metodosPago.remove(provisional),
    );
    final i = _metodosPago.indexOf(provisional);
    if (i != -1) _metodosPago[i] = provisional.copyWith(id: id);
    _logAudit(
      hoja: 'metodo pago',
      celda: 'A${_metodosPago.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$id: $trimmed',
      accion: 'creacion_metodo_pago',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Creación de método de pago "$trimmed"',
    );
    notifyListeners();
  }

  /// Alterna el status de un método de pago (activo/inactivo). No se puede
  /// desactivar uno en uso. Lanza [StateError] (y revierte) si Sheets falla.
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
    final actualizado = actual.copyWith(status: nuevoStatus);
    _metodosPago[idx] = actualizado;
    _logAudit(
      hoja: 'metodo pago',
      celda: 'C${idx + 2}',
      valorAnterior: actual.status.toString(),
      valorNuevo: nuevoStatus.toString(),
      accion: 'cambio_status_metodo_pago',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Método "${actual.nombre}" ${nuevoStatus ? "activado" : "deshabilitado"}',
    );
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'metodo pago', 'id': id, 'data': {'status': nuevoStatus}},
      revertir: () {
        final i = _metodosPago.indexOf(actualizado);
        if (i != -1) _metodosPago[i] = actual;
      },
    );
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
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'metodo pago', 'id': id},
      revertir: () => _metodosPago.insert(idx.clamp(0, _metodosPago.length), actual),
    );
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
      final resultado = await _postAppsScriptJson(
        {'action': 'refrescar_tasas', 'sheet': 'tasas'},
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      );

      final body = resultado.data;
      if (body == null || body['status'] != 'success') {
        Logger.error('SheetsDataService: refrescarTasaHoy falló: ${body?['message']}');
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
  /// Fija (o reemplaza) la tasa manual de [organizacionId]. Lanza
  /// [ArgumentError] si el valor no es positivo y [StateError] (revirtiendo)
  /// si Sheets no lo confirma.
  Future<void> setTasaManualOrganizacion(String organizacionId, String moneda, double valor) async {
    if (valor <= 0) throw ArgumentError('La tasa manual debe ser mayor a 0.');
    final existente = tasaManualOrganizacion(organizacionId);
    if (existente != null) {
      if (existente.valor == valor && existente.moneda == moneda) return; // sin cambios
      final index = _tasas.indexOf(existente);
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
      await _sincronizarConRollback(
        {'action': 'update', 'sheet': 'tasas', 'id': actualizada.id, 'data': actualizada.toMap()},
        revertir: () {
          final i = _tasas.indexOf(actualizada);
          if (i != -1) _tasas[i] = existente;
        },
      );
      return;
    }
    final nueva = TasaRegistro(
      id: '',
      fecha: DateTime.now(),
      moneda: moneda,
      valor: valor,
      fuente: 'manual',
      organizacionId: organizacionId,
    );
    _tasas.insert(0, nueva);
    notifyListeners();
    final idReal = await _crearConRollback(
      'tasas',
      Map.of(nueva.toMap())..remove('id'),
      revertir: () => _tasas.remove(nueva),
    );
    final idx = _tasas.indexOf(nueva);
    if (idx != -1) {
      _tasas[idx] = TasaRegistro(
        id: idReal,
        fecha: nueva.fecha,
        moneda: nueva.moneda,
        valor: nueva.valor,
        fuente: nueva.fuente,
        organizacionId: nueva.organizacionId,
      );
    }
    notifyListeners();
  }

  /// Quita la tasa manual de [organizacionId] (si tenía una configurada).
  Future<void> quitarTasaManualOrganizacion(String organizacionId) async {
    final existente = tasaManualOrganizacion(organizacionId);
    if (existente == null) return;
    final index = _tasas.indexOf(existente);
    _tasas.removeAt(index);
    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'tasas', 'id': existente.id},
      revertir: () => _tasas.insert(index.clamp(0, _tasas.length), existente),
    );
  }

  // ===========================================================================
  // CRUD 14: MONEDA POR ORGANIZACIÓN (hoja moneda_organizacion)
  // ===========================================================================

  /// Fija (o reemplaza) la moneda base de [organizacionId]: si ya tenía una
  /// seleccionada, se actualiza esa misma fila (misma FK, no se duplica).
  /// Lanza [StateError] (y revierte) si Sheets no lo confirma.
  Future<void> setMonedaOrganizacion(String organizacionId, String moneda) async {
    final existenteIdx = _monedasOrganizacion.indexWhere((m) => m.organizacionId == organizacionId);
    if (existenteIdx != -1) {
      final anterior = _monedasOrganizacion[existenteIdx];
      if (anterior.moneda == moneda) return; // sin cambios
      final actualizada = MonedaOrganizacion(
        id: anterior.id,
        organizacionId: organizacionId,
        moneda: moneda,
        actualizadoEn: DateTime.now(),
      );
      _monedasOrganizacion[existenteIdx] = actualizada;
      notifyListeners();
      await _sincronizarConRollback(
        {'action': 'update', 'sheet': 'moneda_organizacion', 'id': actualizada.id, 'data': actualizada.toMap()},
        revertir: () {
          final i = _monedasOrganizacion.indexOf(actualizada);
          if (i != -1) _monedasOrganizacion[i] = anterior;
        },
      );
      return;
    }
    final nueva = MonedaOrganizacion(
      id: '',
      organizacionId: organizacionId,
      moneda: moneda,
      actualizadoEn: DateTime.now(),
    );
    _monedasOrganizacion.insert(0, nueva);
    notifyListeners();
    final idReal = await _crearConRollback(
      'moneda_organizacion',
      Map.of(nueva.toMap())..remove('id'),
      revertir: () => _monedasOrganizacion.remove(nueva),
    );
    final idx = _monedasOrganizacion.indexOf(nueva);
    if (idx != -1) {
      _monedasOrganizacion[idx] = MonedaOrganizacion(
        id: idReal,
        organizacionId: nueva.organizacionId,
        moneda: nueva.moneda,
        actualizadoEn: nueva.actualizadoEn,
      );
    }
    notifyListeners();
  }


  // =========================================================================
  // CRUD DE CÓDIGOS DE TELÉFONO ("codigo de telefonos")
  // =========================================================================

  /// Envía un cambio (catálogos, cierres diarios…) y espera la confirmación
  /// del servidor. Si falla, ejecuta [revertir]
  /// sobre la copia local y lanza [StateError]: así la UI muestra el error
  /// en vez de un éxito que nunca llegó a Sheets.
  Future<void> _sincronizarConRollback(
    Map<String, dynamic> payload, {
    required void Function() revertir,
  }) async {
    final ok = await _postToAppsScript(payload, exigirConfirmacion: true);
    if (ok) return;
    revertir();
    notifyListeners();
    throw StateError(
      'No se pudo guardar en Google Sheets (${payload['sheet']}). Se descartó el cambio; intentá de nuevo.',
    );
  }

  void _reemplazarCodigoTelefono(CodigoTelefono original) {
    final i = _codigosTelefono.indexWhere((c) => c.id == original.id);
    if (i != -1) _codigosTelefono[i] = original;
  }

  void _reemplazarTipoDocumento(TipoDocumento original) {
    final i = _tiposDocumento.indexWhere((t) => t.id == original.id);
    if (i != -1) _tiposDocumento[i] = original;
  }

  /// Crea [data] en [sheet] y devuelve el ID que asignó el servidor. Si el
  /// servidor no lo confirma, ejecuta [revertir] sobre la copia local y
  /// lanza [StateError]. Junto con [_sincronizarConRollback] y
  /// [executeBatchTransaction] es la única forma permitida de escribir en
  /// Sheets (ver docs/estandar-hojas.md).
  Future<String> _crearConRollback(
    String sheet,
    Map<String, dynamic> data, {
    required void Function() revertir,
  }) async {
    final id = await _crearEnServidor(sheet, data);
    if (id != null && id.isNotEmpty) return id;
    revertir();
    notifyListeners();
    throw StateError(
      'No se pudo guardar en Google Sheets ($sheet). Se descartó el cambio; intentá de nuevo.',
    );
  }

  /// Formato de un código de operadora: 0 + 3 dígitos (0414, 0212…).
  static final RegExp formatoCodigoTelefono = RegExp(r'^0\d{3}$');

  /// Códigos de teléfono usados por algún cliente, calculado en una sola
  /// pasada (para listas: evita recorrer los clientes por cada fila).
  Set<String> get codigosTelefonoEnUso {
    final usados = <String>{};
    for (final c in _clientes) {
      final telefono = TelefonoVe.parse(c.telefono);
      if (telefono != null) usados.add(telefono.codigo);
    }
    return usados;
  }

  /// Verifica si un código de teléfono está siendo utilizado por clientes.
  bool isCodigoTelefonoEnUso(String codigo) {
    final cleanCode = codigo.trim();
    if (cleanCode.isEmpty) return false;
    return _clientes.any((c) {
      final telefono = TelefonoVe.parse(c.telefono);
      return telefono != null ? telefono.codigo == cleanCode : c.telefono.trim().startsWith(cleanCode);
    });
  }

  /// Agrega un nuevo código de teléfono a la hoja "codigo de telefonos".
  Future<void> addCodigoTelefono({required String codigo}) async {
    final trimmed = codigo.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El código de teléfono no puede estar vacío');
    }
    if (!formatoCodigoTelefono.hasMatch(trimmed)) {
      throw ArgumentError('El código debe tener 4 dígitos y empezar con 0 (ej: 0414)');
    }

    if (_codigosTelefono.any((c) => c.codigo.trim() == trimmed)) {
      throw ArgumentError('Ya existe el código de teléfono "$trimmed"');
    }

    int maxIdNum = 0;
    for (final c in _codigosTelefono) {
      final digits = RegExp(r'\d+').firstMatch(c.id)?.group(0);
      if (digits != null) {
        final val = int.tryParse(digits) ?? 0;
        if (val > maxIdNum) maxIdNum = val;
      }
    }
    final nextId = 'ct${(maxIdNum + 1).toString().padLeft(8, '0')}';

    final nuevo = CodigoTelefono(id: nextId, codigo: trimmed, status: true);
    _codigosTelefono.add(nuevo);

    _logAudit(
      hoja: 'codigo de telefonos',
      celda: 'A${_codigosTelefono.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$nextId: $trimmed',
      accion: 'creacion_codigo_telefono',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Creación de código de teléfono "$trimmed"',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'create', 'sheet': 'codigo de telefonos', 'data': nuevo.toMap()},
      revertir: () => _codigosTelefono.removeWhere((c) => c.id == nextId),
    );
  }

  /// Actualiza un código de teléfono existente.
  Future<bool> updateCodigoTelefono({required String id, required String nuevoCodigo}) async {
    final idx = _codigosTelefono.indexWhere((c) => c.id == id);
    if (idx == -1) return false;

    final trimmed = nuevoCodigo.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El código de teléfono no puede estar vacío');
    }
    if (!formatoCodigoTelefono.hasMatch(trimmed)) {
      throw ArgumentError('El código debe tener 4 dígitos y empezar con 0 (ej: 0414)');
    }

    if (_codigosTelefono.any((c) => c.id != id && c.codigo.trim() == trimmed)) {
      throw ArgumentError('Ya existe otro registro con el código "$trimmed"');
    }

    final anterior = _codigosTelefono[idx];
    // Los teléfonos de los clientes guardan el código: renombrarlo los
    // dejaría con un código que ya no está en el catálogo.
    if (anterior.codigo.trim() != trimmed && isCodigoTelefonoEnUso(anterior.codigo)) {
      throw ArgumentError(
          'El código ${anterior.codigo} lo usan teléfonos de clientes: no se puede cambiar. Agregá uno nuevo.');
    }
    final actualizado = anterior.copyWith(codigo: trimmed);
    _codigosTelefono[idx] = actualizado;

    _logAudit(
      hoja: 'codigo de telefonos',
      celda: 'B${idx + 2}',
      valorAnterior: anterior.codigo,
      valorNuevo: trimmed,
      accion: 'actualizacion_codigo_telefono',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Código modificado de "${anterior.codigo}" a "$trimmed"',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'codigo de telefonos', 'id': id, 'data': {'codigo': trimmed}},
      revertir: () => _reemplazarCodigoTelefono(anterior),
    );
    return true;
  }

  /// Alterna el status de un código de teléfono (activo/inactivo).
  Future<bool> toggleCodigoTelefonoStatus(String id) async {
    final idx = _codigosTelefono.indexWhere((c) => c.id == id);
    if (idx == -1) return false;

    final actual = _codigosTelefono[idx];
    final nuevoStatus = !actual.status;

    if (!nuevoStatus && isCodigoTelefonoEnUso(actual.codigo)) {
      throw StateError(
        'No se puede deshabilitar el código "${actual.codigo}" porque está asignado a clientes o usuarios registrados.',
      );
    }

    _codigosTelefono[idx] = actual.copyWith(status: nuevoStatus);

    _logAudit(
      hoja: 'codigo de telefonos',
      celda: 'C${idx + 2}',
      valorAnterior: actual.status.toString(),
      valorNuevo: nuevoStatus.toString(),
      accion: 'cambio_status_codigo_telefono',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Código "${actual.codigo}" ${nuevoStatus ? "activado" : "deshabilitado"}',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'codigo de telefonos', 'id': id, 'data': {'status': nuevoStatus}},
      revertir: () => _reemplazarCodigoTelefono(actual),
    );
    return true;
  }

  /// Elimina un código de teléfono si no está en uso.
  Future<bool> deleteCodigoTelefono(String id) async {
    final idx = _codigosTelefono.indexWhere((c) => c.id == id);
    if (idx == -1) return false;

    final actual = _codigosTelefono[idx];
    if (isCodigoTelefonoEnUso(actual.codigo)) {
      throw StateError(
        'No se puede eliminar el código "${actual.codigo}" porque está en uso por clientes o usuarios registrados.',
      );
    }

    _codigosTelefono.removeAt(idx);

    _logAudit(
      hoja: 'codigo de telefonos',
      celda: 'A${idx + 2}',
      valorAnterior: actual.codigo,
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_codigo_telefono',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Eliminación del código de teléfono "${actual.codigo}"',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'codigo de telefonos', 'id': id},
      revertir: () => _codigosTelefono.insert(idx.clamp(0, _codigosTelefono.length), actual),
    );
    return true;
  }

  // =========================================================================
  // CRUD DE TIPOS DE DOCUMENTO ("tipo de documento")
  // =========================================================================

  /// Siglas de tipo de documento usadas por clientes o usuarios (en mayúscula).
  Set<String> get tiposDocumentoEnUso => {
        for (final c in _clientes) c.tipoDocumento.trim().toUpperCase(),
        for (final u in _usuarios) u.tipoDocumento.trim().toUpperCase(),
      }..remove('');

  /// Verifica si un tipo de documento está siendo utilizado por clientes o usuarios.
  bool isTipoDocumentoEnUso(String tipo) {
    final cleanTipo = tipo.trim().toUpperCase();
    if (cleanTipo.isEmpty) return false;
    final clienteUsa = _clientes.any((c) => c.tipoDocumento.trim().toUpperCase() == cleanTipo);
    final usuarioUsa = _usuarios.any((u) => u.tipoDocumento.trim().toUpperCase() == cleanTipo);
    return clienteUsa || usuarioUsa;
  }

  /// Agrega un nuevo tipo de documento a la hoja "tipo de documento".
  Future<void> addTipoDocumento({
    required String tipo,
    required String descripcion,
  }) async {
    final cleanTipo = tipo.trim().toUpperCase();
    final cleanDesc = descripcion.trim();

    if (cleanTipo.isEmpty) {
      throw ArgumentError('El tipo de documento no puede estar vacío');
    }
    if (cleanDesc.isEmpty) {
      throw ArgumentError('La descripción no puede estar vacía');
    }

    if (_tiposDocumento.any((t) => t.tipo.trim().toUpperCase() == cleanTipo)) {
      throw ArgumentError('Ya existe un tipo de documento con la letra "$cleanTipo"');
    }

    int maxIdNum = 0;
    for (final t in _tiposDocumento) {
      final digits = RegExp(r'\d+').firstMatch(t.id)?.group(0);
      if (digits != null) {
        final val = int.tryParse(digits) ?? 0;
        if (val > maxIdNum) maxIdNum = val;
      }
    }
    final nextId = 'td${(maxIdNum + 1).toString().padLeft(8, '0')}';

    final nuevo = TipoDocumento(
      id: nextId,
      tipo: cleanTipo,
      descripcion: cleanDesc,
      status: true,
    );
    _tiposDocumento.add(nuevo);

    _logAudit(
      hoja: 'tipo de documento',
      celda: 'A${_tiposDocumento.length + 1}',
      valorAnterior: 'null',
      valorNuevo: '$nextId: $cleanTipo - $cleanDesc',
      accion: 'creacion_tipo_documento',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Creación de tipo de documento "$cleanTipo" ($cleanDesc)',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'create', 'sheet': 'tipo de documento', 'data': nuevo.toMap()},
      revertir: () => _tiposDocumento.removeWhere((t) => t.id == nextId),
    );
  }

  /// Actualiza un tipo de documento existente.
  Future<bool> updateTipoDocumento({
    required String id,
    required String nuevoTipo,
    required String nuevaDescripcion,
  }) async {
    final idx = _tiposDocumento.indexWhere((t) => t.id == id);
    if (idx == -1) return false;

    final cleanTipo = nuevoTipo.trim().toUpperCase();
    final cleanDesc = nuevaDescripcion.trim();

    if (cleanTipo.isEmpty) {
      throw ArgumentError('El tipo de documento no puede estar vacío');
    }
    if (cleanDesc.isEmpty) {
      throw ArgumentError('La descripción no puede estar vacía');
    }

    if (_tiposDocumento.any((t) => t.id != id && t.tipo.trim().toUpperCase() == cleanTipo)) {
      throw ArgumentError('Ya existe otro registro con el tipo "$cleanTipo"');
    }

    final anterior = _tiposDocumento[idx];
    // Clientes y usuarios guardan la sigla: si está en uso, solo se puede
    // cambiar la descripción.
    if (anterior.tipo.trim().toUpperCase() != cleanTipo && isTipoDocumentoEnUso(anterior.tipo)) {
      throw ArgumentError(
          'El tipo ${anterior.tipo} está en uso por clientes o usuarios: solo se puede cambiar la descripción.');
    }
    final actualizado = anterior.copyWith(tipo: cleanTipo, descripcion: cleanDesc);
    _tiposDocumento[idx] = actualizado;

    _logAudit(
      hoja: 'tipo de documento',
      celda: 'B${idx + 2}',
      valorAnterior: '${anterior.tipo} - ${anterior.descripcion}',
      valorNuevo: '$cleanTipo - $cleanDesc',
      accion: 'actualizacion_tipo_documento',
      norma: 'ISO 8000 §4.2',
      observaciones: 'Tipo de documento modificado a "$cleanTipo - $cleanDesc"',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {
        'action': 'update',
        'sheet': 'tipo de documento',
        'id': id,
        'data': {'tipo': cleanTipo, 'descripcion': cleanDesc},
      },
      revertir: () => _reemplazarTipoDocumento(anterior),
    );
    return true;
  }

  /// Alterna el status de un tipo de documento (activo/inactivo).
  Future<bool> toggleTipoDocumentoStatus(String id) async {
    final idx = _tiposDocumento.indexWhere((t) => t.id == id);
    if (idx == -1) return false;

    final actual = _tiposDocumento[idx];
    final nuevoStatus = !actual.status;

    if (!nuevoStatus && isTipoDocumentoEnUso(actual.tipo)) {
      throw StateError(
        'No se puede deshabilitar el tipo de documento "${actual.tipo}" porque está asignado a clientes o usuarios registrados.',
      );
    }

    _tiposDocumento[idx] = actual.copyWith(status: nuevoStatus);

    _logAudit(
      hoja: 'tipo de documento',
      celda: 'D${idx + 2}',
      valorAnterior: actual.status.toString(),
      valorNuevo: nuevoStatus.toString(),
      accion: 'cambio_status_tipo_documento',
      norma: 'ISO 8000 §5.3',
      observaciones: 'Tipo de documento "${actual.tipo}" ${nuevoStatus ? "activado" : "deshabilitado"}',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'update', 'sheet': 'tipo de documento', 'id': id, 'data': {'status': nuevoStatus}},
      revertir: () => _reemplazarTipoDocumento(actual),
    );
    return true;
  }

  /// Elimina un tipo de documento si no está en uso.
  Future<bool> deleteTipoDocumento(String id) async {
    final idx = _tiposDocumento.indexWhere((t) => t.id == id);
    if (idx == -1) return false;

    final actual = _tiposDocumento[idx];
    if (isTipoDocumentoEnUso(actual.tipo)) {
      throw StateError(
        'No se puede eliminar el tipo de documento "${actual.tipo}" porque está en uso por clientes o usuarios registrados.',
      );
    }

    _tiposDocumento.removeAt(idx);

    _logAudit(
      hoja: 'tipo de documento',
      celda: 'A${idx + 2}',
      valorAnterior: actual.tipo,
      valorNuevo: 'ELIMINADO',
      accion: 'eliminacion_tipo_documento',
      norma: 'GDPR Art. 17 / ISO 27001',
      observaciones: 'Eliminación del tipo de documento "${actual.tipo}"',
    );

    notifyListeners();
    await _sincronizarConRollback(
      {'action': 'delete', 'sheet': 'tipo de documento', 'id': id},
      revertir: () => _tiposDocumento.insert(idx.clamp(0, _tiposDocumento.length), actual),
    );
    return true;
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


/// Resultado de [SheetsDataService.registrarAbono].
enum ResultadoAbono {
  /// El servidor confirmó el lote.
  registrado,

  /// El servidor rechazó el lote (y lo revirtió): se puede reintentar.
  rechazado,

  /// No hubo respuesta: no se sabe si se aplicó. Se releyeron los datos;
  /// hay que revisar el historial de la factura antes de reintentar.
  sinConfirmar,
}

/// Hojas pedidas a la vez al Apps Script (ver `_filasDelServidor`).
class _LoteLectura {
  final hojas = <String>{};
  bool programado = false;
  final resultado = Completer<Map<String, List<List<String>>>?>();
}
