// Servidor simulado para tests que escriben en Sheets (ver
// docs/estandar-hojas.md, R4: toda escritura espera la confirmación del
// servidor y se revierte si falla, así que sin servidor nada queda guardado).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

import 'test_sheets_config.dart';

const organizacionDePrueba = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

/// - Lecturas gviz: fallan (500), así quedan los datos de respaldo.
/// - Escrituras al Apps Script: responden [respuesta] o, si es `null`, éxito
///   con un ID nuevo (`x00000001`, …). Los lotes devuelven `transactionId`.
/// - Guarda cada payload enviado en [enviados].
class ServidorSimulado implements HttpClientAdapter {
  String? respuesta;
  final enviados = <Map<String, dynamic>>[];

  /// Prefijos de ID por hoja (los mismos que ID_PREFIXES del script). Los IDs
  /// arrancan en 90000001 por hoja: `c90000001`, `p90000001`…
  static const prefijos = {
    'clientes': 'c', 'inventario': 'p', 'galeria': 'g', 'ventas': 'v', 'venta_items': 'vi',
    'abonos': 'ab', 'compras_divisas': 'd', 'usuarios': 'u', 'tasas': 't',
    'moneda_organizacion': 'mo', 'creditos_clientes': 'cr', 'codigo de telefonos': 'ct',
    'tipo de documento': 'td', 'resumen_diario': 'rd', 'metodo pago': 'mp',
    'usuario_organizacion': 'uo', 'seguridad': 'sg', 'checklist_iso': 'ck', 'cuarentena': 'cq',
    'audit_log': 'al', 'reporte_migracion': 'rm', 'config_notificaciones': 'cn', 'tipos_notificacion': 'tn', 'plantillas_notificacion': 'pn', 'bancos': 'bn', 'cuentas_bancarias': 'cb',
  };
  final _contadores = <String, int>{};

  /// Cantidad de lecturas gviz recibidas, por hoja.
  final lecturas = <String, int>{};

  /// Opt-in: CSV que devuelve la lectura gviz de cada hoja (las demás
  /// responden sin datos, ver [lecturaSinDatos]).
  final csvPorHoja = <String, String>{};

  /// Opt-in: hojas que devuelve la acción `leer_hojas` del Apps Script. Si es
  /// `null`, la acción responde como un script viejo (sin `hojas`) y la app
  /// vuelve a leer por gviz.
  Map<String, List<List<String>>>? hojasServidor;

  /// Opt-in: tokens que el servidor rechaza como vencidos o revocados
  /// (`code: "no_autenticado"`), como hace el script con un token inválido.
  final tokensRechazados = <String>{};

  String _nuevoId(Map<String, dynamic> payload) {
    final hoja = payload['sheet']?.toString() ?? '';
    final data = payload['data'];
    if (hoja == 'organizaciones' && data is Map && data['id'] != null) return data['id'].toString();
    final n = _contadores[hoja] = (_contadores[hoja] ?? 90000000) + 1;
    return '${prefijos[hoja] ?? 'x'}$n';
  }

  /// Opt-in: en los lotes, genera IDs para las altas (en `generatedIds`).
  bool generarIdsEnLotes = false;

  /// Opt-in: valor que deja en el servidor cada `increment` del lote, por
  /// `'hoja/id'` (vuelve en `results`, como el script real).
  final valoresIncremento = <String, num>{};

  void rechazar([String mensaje = 'falló']) => respuesta = '{"status":"error","message":"$mensaje"}';
  void confirmar() => respuesta = null;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final gviz = o.uri.toString().contains('gviz');
    if (gviz) {
      final hoja = o.uri.queryParameters['sheet'] ?? '';
      lecturas[hoja] = (lecturas[hoja] ?? 0) + 1;
      // Sin CSV propio, la lectura "falla" con un encabezado que no es el de
      // ninguna hoja: la app la descarta igual que un error de red (y sigue
      // con los datos que tenía), pero sin un HTTP 500 que el interceptor de
      // Dio registraría como error en cada lectura de cada test.
      final csv = csvPorHoja[hoja];
      return csv == null
          ? lecturaSinDatos()
          : ResponseBody.fromBytes(utf8.encode(csv), 200, headers: {Headers.contentTypeHeader: ['text/csv']});
    }
    final payload = o.data == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) as Map : o.data as Map);
    enviados.add(payload);
    if (tokensRechazados.contains(payload['access_token'])) {
      return ResponseBody.fromBytes(
          utf8.encode(jsonEncode({
            'status': 'error',
            'code': 'no_autenticado',
            'message': 'La sesión de Google venció o no es válida. Volvé a iniciar sesión.',
          })),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    final servidor = hojasServidor;
    if (payload['action'] == 'leer_hojas' && servidor != null && respuesta == null) {
      final pedidas = (payload['hojas'] as List).cast<String>();
      return ResponseBody.fromBytes(
          utf8.encode(jsonEncode({
            'status': 'success',
            'hojas': {for (final h in pedidas) if (servidor.containsKey(h)) h: servidor[h]},
          })),
          200,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    final generados = <String, dynamic>{};
    final resultados = <Map<String, dynamic>>[];
    for (final op in (payload['operations'] as List? ?? const []).cast<Map>()) {
      if (generarIdsEnLotes && op['action'] == 'create') {
        generados[op['sheet'].toString()] = _nuevoId({'sheet': op['sheet']});
      }
      final clave = '${op['sheet']}/${op['id']}';
      if (op['action'] == 'increment' && valoresIncremento.containsKey(clave)) {
        resultados.add({
          'action': 'increment',
          'sheet': op['sheet'],
          'id': op['id'],
          'field': op['field'],
          'value': valoresIncremento[clave],
        });
      }
    }
    final body = respuesta ??
        jsonEncode({
          'status': 'success',
          'id': _nuevoId(payload),
          'transactionId': payload['transactionId'] ?? 'tx',
          'generatedIds': generados,
          'results': resultados,
        });
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

/// Lectura gviz que "falla" sin un HTTP 500: un encabezado que no es el de
/// ninguna hoja. La app la descarta igual que un error de red (y sigue con
/// los datos que tenía), pero el interceptor de Dio no la registra como
/// error en cada lectura de cada test (ruido en script/log_script.txt).
ResponseBody lecturaSinDatos() => ResponseBody.fromBytes(
      utf8.encode('"sin_datos_en_el_servidor_simulado"\n'),
      200,
      headers: {Headers.contentTypeHeader: ['text/csv']},
    );

/// Servicio inicializado (con los datos de respaldo) contra un
/// [ServidorSimulado], en la organización de prueba y con un usuario.
/// Con [inicializar] en `false` no se cargan los datos de respaldo (listas
/// vacías), para tests que arman sus propios datos.
Future<(SheetsDataService, ServidorSimulado)> servicioConServidor({
  String? usuario = 'xhnl21@gmail.com',
  bool inicializar = true,
  bool datosDeRespaldo = true,
}) async {
  final servidor = ServidorSimulado();
  final ds = SheetsDataService(
    spreadsheetId: testSpreadsheetId,
    appsScriptUrl: testAppsScriptUrl,
    dio: Dio()..httpClientAdapter = servidor,
    datosDeRespaldo: datosDeRespaldo,
  );
  if (inicializar) await ds.initialize();
  ds.setCurrentOrganizacion(organizacionDePrueba);
  ds.setCurrentUsuario(usuario);
  return (ds, servidor);
}
