import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';
import '../test_servidor.dart';

const _org = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';

/// gviz falla (datos de respaldo). El Apps Script responde [respuesta] o, si
/// es `null`, éxito con un id nuevo en cada alta. Guarda lo enviado.
class _Servidor implements HttpClientAdapter {
  String? respuesta;
  final enviados = <Map<String, dynamic>>[];
  int _ids = 100;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final gviz = o.uri.toString().contains('gviz');
    if (!gviz && o.data != null) {
      enviados.add(Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) as Map : o.data as Map));
    }
    if (gviz) return lecturaSinDatos();
    final body = respuesta ?? '{"status":"success","id":"x${(++_ids).toString().padLeft(8, '0')}"}';
    return ResponseBody.fromBytes(utf8.encode(body), 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Servidor servidor;
  late SheetsDataService ds;

  setUp(() async {
    servidor = _Servidor();
    ds = SheetsDataService(
      spreadsheetId: testSpreadsheetId,
      appsScriptUrl: testAppsScriptUrl,
      dio: Dio()..httpClientAdapter = servidor,
    );
    await ds.initialize();
    ds.setCurrentOrganizacion(_org);
    ds.setCurrentUsuario('xhnl21@gmail.com');
  });

  void rechazar() => servidor.respuesta = '{"status":"error","message":"falló"}';
  Map<String, dynamic> ultimo(String accion) => servidor.enviados.lastWhere((e) => e['action'] == accion);

  group('lectura: formato con id y formato anterior (hoja sin migrar)', () {
    test('cada modelo reconoce su id por el prefijo', () {
      expect(UsuarioOrganizacion.fromRow(['uo00000003', 'A@x.com', 'org']).id, 'uo00000003');
      expect(UsuarioOrganizacion.fromRow(['a@x.com', 'org']).usuarioEmail, 'a@x.com');
      expect(Seguridad.fromRow(['sg00000001', 'TRUE', 'FALSE', 'FALSE', 'a@x.com']).biometrico, isTrue);
      expect(Seguridad.fromRow(['TRUE', 'FALSE', 'FALSE', 'a@x.com']).usuarioEmail, 'a@x.com');
      expect(ChecklistISO.fromRow(['ck00000002', '5', 'Backup', 'ISO', '☑', 'e', '2026-01-01', 'org']).nro, 5);
      expect(ChecklistISO.fromRow(['5', 'Backup', 'ISO', '☑', 'e', '2026-01-01', 'org']).control, 'Backup');
      expect(RegistroCuarentena.fromRow(['cq00000001', 'v1', 'ventas']).hojaOrigen, 'ventas');
      expect(RegistroCuarentena.fromRow(['3c82e14c', 'ventas']).idRegistroOriginal, '3c82e14c');
      expect(AuditLog.fromRow(['al00000009', '2026-01-01T00:00:00Z', 'u', 'clientes']).hoja, 'clientes');
      expect(ReporteMigracion.fromRow(['rm00000001', 'Inicio', '2026']).metrica, 'Inicio');
      expect(ReporteMigracion.fromRow(['Inicio', '2026']).id, isEmpty);
    });
  });

  group('cuarentena', () {
    test('alta con id del servidor, edición y baja por id', () async {
      await ds.addCuarentena(RegistroCuarentena(
        idRegistroOriginal: 'v9', hojaOrigen: 'ventas', fechaDeteccion: DateTime(2026),
        motivoCuarentena: 'm', datosOriginalesJson: '{}', estado: 'PENDIENTE', resolucion: '', hashEvidencia: 'h'));
      final creado = ds.cuarentenas.firstWhere((c) => c.idRegistroOriginal == 'v9');
      expect(creado.id, startsWith('x'));
      expect(ultimo('create')['data'].containsKey('id'), isFalse);

      await ds.updateCuarentena(creado.copyWith(estado: 'CORREGIDO', resolucion: 'ok', idRegistroOriginal: 'cambiado'));
      final editado = ds.cuarentenas.firstWhere((c) => c.id == creado.id);
      expect(editado.estado, 'CORREGIDO');
      expect(editado.idRegistroOriginal, 'v9', reason: 'solo se editan estado y resolución');

      await ds.deleteCuarentena(creado.id);
      expect(ultimo('delete')['data'], {'organizacion_id': _org});
      expect(ds.cuarentenas.any((c) => c.id == creado.id), isFalse);
    });

    test('si Sheets rechaza el alta, no queda en el teléfono', () async {
      rechazar();
      await expectLater(
        ds.addCuarentena(RegistroCuarentena(
          idRegistroOriginal: 'v9', hojaOrigen: 'ventas', fechaDeteccion: DateTime(2026),
          motivoCuarentena: 'm', datosOriginalesJson: '{}', estado: 'PENDIENTE', resolucion: '', hashEvidencia: 'h')),
        throwsA(isA<StateError>()),
      );
      expect(ds.cuarentenas.any((c) => c.idRegistroOriginal == 'v9'), isFalse);
    });
  });

  group('checklist ISO', () {
    test('el nro nuevo es el máximo + 1, no la cantidad + 1', () async {
      final max = ds.checklistIsos.map((c) => c.nro).reduce((a, b) => a > b ? a : b);
      await ds.addChecklistIso(ChecklistISO(nro: 0, control: 'Nuevo', norma: 'ISO', estado: '☐', evidencia: '', timestamp: DateTime(2026)));
      expect(ds.checklistIsos.firstWhere((c) => c.control == 'Nuevo').nro, max + 1);
    });

    test('editar sin cambiar el estado conserva la fecha de verificación', () async {
      final item = ds.checklistIsos.first;
      await ds.updateChecklistIso(item.copyWith(evidencia: 'nueva', timestamp: DateTime(1999)));
      final editado = ds.checklistIsos.firstWhere((c) => c.id == item.id);
      expect(editado.evidencia, 'nueva');
      expect(editado.timestamp, item.timestamp);
    });

    test('toggle rechazado vuelve al estado anterior', () async {
      final item = ds.checklistIsos.first;
      rechazar();
      await expectLater(ds.toggleChecklistEstado(item.id), throwsA(isA<StateError>()));
      expect(ds.checklistIsos.firstWhere((c) => c.id == item.id).estado, item.estado);
      expect(ultimo('toggle_checklist')['id'], item.id);
    });

    test('no se modifica un control de otra organización', () async {
      final item = ds.checklistIsos.first;
      ds.setCurrentOrganizacion('otra-org');
      await expectLater(ds.deleteChecklistIso(item.id), throwsA(isA<ArgumentError>()));
    });
  });

  group('reporte de migración', () {
    test('editar y eliminar por id (no por posición en la lista)', () async {
      final segundo = ds.reportesMigracion[1];
      await ds.updateReporteMigracion(segundo.copyWith(valorEstado: 'Cambiado'));
      expect(ds.reportesMigracion[1].valorEstado, 'Cambiado');
      expect(ds.reportesMigracion[0].valorEstado, isNot('Cambiado'));
      expect(ultimo('update')['id'], segundo.id);
      await ds.deleteReporteMigracion(segundo.id);
      expect(ds.reportesMigracion.any((r) => r.id == segundo.id), isFalse);
    });
  });

  group('bitácora de auditoría', () {
    test('el alta manual se firma con el usuario actual, no con uno inventado', () async {
      await ds.addAuditLogManual(AuditLog(
        timestampIso8601: DateTime(2026), usuario: 'Auditor Manual', hoja: 'global', celda: 'A1',
        valorAnterior: '', valorNuevo: '', accion: 'checkpoint', normaAplicada: 'ISO', observaciones: ''));
      expect(ultimo('create')['data']['usuario'], 'xhnl21@gmail.com');
      expect(ds.auditLogs.first.id, startsWith('x'));
    });

    test('sin usuario identificado no se puede firmar', () async {
      ds.setCurrentUsuario(null);
      await expectLater(
        ds.addAuditLogManual(AuditLog(
          timestampIso8601: DateTime(2026), usuario: '', hoja: 'g', celda: 'A1', valorAnterior: '',
          valorNuevo: '', accion: 'c', normaAplicada: '', observaciones: '')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('seguridad', () {
    test('si Sheets rechaza el cambio de método, vuelve al anterior', () async {
      final antes = ds.seguridad.metodoActivo;
      rechazar();
      await expectLater(ds.setMetodoSeguridad('dos_factores'), throwsA(isA<StateError>()));
      expect(ds.seguridad.metodoActivo, antes);
    });
  });

  group('usuarios y membresías', () {
    test('alta: usuario y membresía con ids del servidor', () async {
      final ok = await ds.addUsuario(const Usuario(id: 'u-local', email: 'Ana@X.com', nombre: 'Ana'), organizacionId: _org);
      expect(ok, isTrue);
      final ana = ds.usuarios.firstWhere((u) => u.email == 'ana@x.com');
      expect(ana.id, startsWith('x'));
      expect(servidor.enviados.firstWhere((e) => e['sheet'] == 'usuarios')['data'].containsKey('id'), isFalse);
      expect(ds.resolverAcceso('ana@x.com').organizacionId, _org);
    });

    test('alta rechazada: no queda ni el usuario ni su acceso', () async {
      rechazar();
      final ok = await ds.addUsuario(const Usuario(id: 'u-local', email: 'ana@x.com'), organizacionId: _org);
      expect(ok, isFalse);
      expect(ds.usuarios.any((u) => u.email == 'ana@x.com'), isFalse);
      expect(ds.resolverAcceso('ana@x.com').organizacionId, isNull);
    });

    test('cambiar de organización actualiza la membresía por su id', () async {
      final usuario = ds.usuarios.firstWhere((u) => u.email == 'neidapulgar1989@gmail.com');
      final membresia = ds.usuarioOrganizaciones.firstWhere((m) => m.usuarioEmail == usuario.email);
      await ds.addOrganizacion('Org B');
      final orgB = ds.organizaciones.firstWhere((o) => o.nombre == 'Org B').id;
      expect(await ds.updateUsuario(usuario, organizacionId: orgB), isTrue);
      final update = servidor.enviados.lastWhere((e) => e['sheet'] == 'usuario_organizacion');
      expect(update['action'], 'update');
      expect(update['id'], membresia.id);
    });
  });
}
