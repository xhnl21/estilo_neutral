import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/presentation/cubits/miembros_organizacion/miembros_organizacion_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/miembros_organizacion/miembros_organizacion_state.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_fake_dio.dart';
import '../test_sheets_config.dart';
import '../test_servidor.dart';

const _org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

/// Servicio sin red (las lecturas de Sheets fallan) con los datos de
/// respaldo: 2 usuarios con membresía en la organización por defecto.
/// Lecturas gviz fallan (datos de respaldo); el Apps Script responde
/// [respuesta] o, si es `null`, éxito (con un id nuevo en cada alta).
class _Servidor implements HttpClientAdapter {
  String? respuesta;
  int _ids = 0;

  /// Hojas que gviz sirve como CSV (el resto falla). Para simular datos que
  /// solo pueden venir de Sheets, como una membresía a una organización que
  /// otro dispositivo borró.
  final Map<String, String> hojas;

  _Servidor([this.hojas = const {}]);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final gviz = o.uri.toString().contains('gviz');
    if (gviz) {
      final csv = hojas[o.uri.queryParameters['sheet']];
      if (csv == null) return lecturaSinDatos();
      return ResponseBody.fromBytes(utf8.encode(csv), 200, headers: {Headers.contentTypeHeader: ['text/csv']});
    }
    final body = respuesta ?? '{"status":"success","id":"x${(++_ids).toString().padLeft(8, '0')}"}';
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Future<(SheetsDataService, _Servidor)> servicioConServidor([Map<String, String> hojas = const {}]) async {
  final servidor = _Servidor(hojas);
  final ds = SheetsDataService(
    spreadsheetId: testSpreadsheetId,
    appsScriptUrl: testAppsScriptUrl,
    dio: Dio()..httpClientAdapter = servidor,
  );
  await ds.initialize();
  return (ds, servidor);
}

Future<SheetsDataService> servicioOffline() async {
  final dio = Dio()..httpClientAdapter = FakeHttpClientAdapter(statusCode: 500);
  final ds = SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: '', dio: dio);
  await ds.initialize();
  return ds;
}

void main() {
  group('C1 · resolverAcceso: la hoja usuarios decide quién entra', () {
    late SheetsDataService ds;
    setUp(() async => ds = await servicioOffline());

    test('usuario con membresía en una organización existente entra', () {
      final acceso = ds.resolverAcceso('  XHNL21@gmail.com ');
      expect(acceso.organizacionId, _org);
      expect(acceso.motivo, isNull);
    });

    test('un email que no está en usuarios no entra (ya no hay fallback)', () {
      final acceso = ds.resolverAcceso('intruso@gmail.com');
      expect(acceso.organizacionId, isNull);
      expect(acceso.motivo, contains('no está registrada'));
    });

    test('usuario sin membresía no entra', () async {
      final (conServidor, _) = await servicioConServidor({
        'usuarios': '"id","email","nombre"\n"u00000001","xhnl21@gmail.com","X"',
        'organizaciones': '"id","nombre"\n"$_org","Estilo Neutral"',
        'usuario_organizacion': '"id","usuario_email","organizacion_id"\n"uo00000001","otra@x.com","$_org"',
      });
      ds = conServidor;
      final acceso = ds.resolverAcceso('xhnl21@gmail.com');
      expect(acceso.organizacionId, isNull);
      expect(acceso.motivo, contains('no pertenece'));
    });

    test('membresía a una organización inexistente no entra', () async {
      // Solo puede venir de Sheets (otro dispositivo borró la organización):
      // la app ya no deja asignar una organización que no existe.
      final (conServidor, _) = await servicioConServidor({
        'usuarios': '"id","email","nombre"\n"u00000001","xhnl21@gmail.com","X"',
        'organizaciones': '"id","nombre"\n"$_org","Estilo Neutral"',
        'usuario_organizacion': '"id","usuario_email","organizacion_id"\n"uo00000001","xhnl21@gmail.com","org-borrada"',
      });
      ds = conServidor;
      final acceso = ds.resolverAcceso('xhnl21@gmail.com');
      expect(acceso.organizacionId, isNull);
      expect(acceso.motivo, contains('ya no existe'));
    });

    test('no se puede asignar una organización que no existe', () async {
      final (conServidor, _) = await servicioConServidor();
      ds = conServidor;
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await expectLater(ds.updateUsuario(usuario, organizacionId: 'org-borrada'), throwsA(isA<ArgumentError>()));
      expect(ds.organizacionIdForUsuario('xhnl21@gmail.com'), _org);
    });

    test('"Quitar acceso" (eliminar usuario) impide entrar', () async {
      final (conServidor, _) = await servicioConServidor();
      ds = conServidor;
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'xhnl21@gmail.com');
      await ds.deleteUsuario(usuario);
      expect(ds.resolverAcceso('xhnl21@gmail.com').organizacionId, isNull);
    });
  });

  test('esperarCargaInicial espera la carga en curso y no lanza sin red', () async {
    final dio = Dio()..httpClientAdapter = FakeHttpClientAdapter(statusCode: 500);
    final ds = SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: '', dio: dio);
    final inicial = ds.initialize(); // como ServiceLocator: sin await
    await ds.esperarCargaInicial();
    expect(ds.isLoading, isFalse);
    expect(ds.usuarios, isNotEmpty); // datos de respaldo
    await inicial;
  });

  group('C2 · MiembrosOrganizacionCubit', () {
    late SheetsDataService ds;
    late _Servidor servidor;
    late String orgB;
    setUp(() async {
      (ds, servidor) = await servicioConServidor();
      await ds.addOrganizacion('Org B');
      orgB = ds.organizaciones.firstWhere((o) => o.nombre == 'Org B').id;
    });

    test('agrega al usuario elegido, no al primero de la lista', () async {
      final cubit = MiembrosOrganizacionCubit(dataService: ds, organizacionId: orgB);
      expect(cubit.state.disponibles.length, 2);
      final primero = cubit.state.disponibles.first.email;
      final segundo = cubit.state.disponibles.last.email;
      expect(cubit.state.seleccionadoEmail, primero);

      cubit.seleccionar(segundo);
      await cubit.agregarSeleccionado();

      expect(ds.organizacionIdForUsuario(segundo), orgB);
      expect(ds.organizacionIdForUsuario(primero), _org);
      expect(cubit.state.miembros.map((u) => u.email), [segundo]);
      expect(cubit.state.disponibles.map((u) => u.email), [primero]);
      expect(cubit.state.messageType, MiembrosMessageType.success);
      await cubit.close();
    });

    test('si Sheets rechaza, la membresía vuelve a como estaba y se avisa', () async {
      final cubit = MiembrosOrganizacionCubit(dataService: ds, organizacionId: orgB);
      final email = cubit.state.disponibles.first.email;
      servidor.respuesta = '{"status":"error","message":"falló"}';

      await cubit.agregarSeleccionado();

      expect(ds.organizacionIdForUsuario(email), _org);
      expect(cubit.state.miembros, isEmpty);
      expect(cubit.state.messageType, MiembrosMessageType.warning);
      await cubit.close();
    });

    test('la elección se conserva cuando cambian las membresías', () async {
      final cubit = MiembrosOrganizacionCubit(dataService: ds, organizacionId: orgB);
      final segundo = cubit.state.disponibles.last.email;
      cubit.seleccionar(segundo);

      ds.notifyListeners(); // p. ej. un refresco de datos
      expect(cubit.state.seleccionadoEmail, segundo);
      await cubit.close();
    });

    test('mover saca al miembro de la lista', () async {
      final cubit = MiembrosOrganizacionCubit(dataService: ds, organizacionId: _org);
      final miembro = cubit.state.miembros.first;
      await cubit.mover(miembro, orgB);
      expect(cubit.state.miembros.any((u) => u.email == miembro.email), isFalse);
      await cubit.close();
    });
  });
}
