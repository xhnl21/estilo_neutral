import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/reporting/presentation/cubit/reporting_cubit.dart';
import 'package:estilo_neutral/models/resumen_diario.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';
import '../test_servidor.dart';

/// gviz falla (datos de respaldo); el Apps Script responde [respuesta] y se
/// guarda cada payload enviado.
class _Servidor implements HttpClientAdapter {
  /// `null`: responde éxito (con un id nuevo si es un create).
  String? respuesta;
  final enviados = <Map<String, dynamic>>[];
  int _ultimoId = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final gviz = o.uri.toString().contains('gviz');
    String body = 'error';
    if (!gviz && o.data != null) {
      final payload = Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) as Map : o.data as Map);
      enviados.add(payload);
      body = respuesta ??
          (payload['action'] == 'create'
              ? '{"status":"success","id":"rd${(++_ultimoId).toString().padLeft(8, '0')}"}'
              : '{"status":"success"}');
    }
    if (gviz) return lecturaSinDatos();
    return ResponseBody.fromBytes(
      utf8.encode(body),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

ResumenDiario cierre(String fecha, double usd) => ResumenDiario(
      fecha: DateTime.parse(fecha),
      nroVentas: 1,
      totalBs: 0,
      totalUsd: usd,
      tasaBcv: 0,
      tasaUsd: 0,
      usdComprados: 0,
      usdVendidos: 0,
    );

void main() {
  const orgA = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';
  const orgB = 'org-b';
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
    ds.setCurrentOrganizacion(orgA);
  });

  ResumenDiario? cierreDe(String fecha) =>
      ds.resumenesDiarios.where((r) => r.fechaIso == fecha).firstOrNull;

  group('C4 · los cierres se guardan en Sheets', () {
    test('crear envía el cierre y guarda el ID que asigna el servidor', () async {
      await ds.addResumenDiario(cierre('2026-10-06', 10));
      final create = servidor.enviados.last;
      expect(create['action'], 'create');
      expect(create['sheet'], 'resumen_diario');
      expect(create['data']['fecha'], '2026-10-06');
      expect(create['data']['organizacion_id'], orgA);
      expect(create['data'].containsKey('id'), isFalse); // lo genera el servidor
      expect(cierreDe('2026-10-06')?.id, 'rd00000001');
      expect(cierreDe('2026-10-06')?.totalUsd, 10);
    });

    test('si Sheets rechaza, el cierre no queda solo en el teléfono', () async {
      servidor.respuesta = '{"status":"error","message":"falló"}';
      await expectLater(ds.addResumenDiario(cierre('2026-10-06', 10)), throwsA(isA<StateError>()));
      expect(cierreDe('2026-10-06'), isNull);
    });

    test('editar y eliminar se envían por ID', () async {
      await ds.addResumenDiario(cierre('2026-10-06', 10));
      final id = cierreDe('2026-10-06')!.id;
      await ds.updateResumenDiario(cierre('2026-10-06', 15).copyWith(id: id));
      expect(cierreDe('2026-10-06')?.totalUsd, 15);
      await ds.deleteResumenDiario(id);
      final update = servidor.enviados.firstWhere((e) => e['action'] == 'update');
      final delete = servidor.enviados.firstWhere((e) => e['action'] == 'delete');
      expect(update['id'], id);
      expect(delete['id'], id);
      expect(cierreDe('2026-10-06'), isNull);
    });

    test('si Sheets rechaza una edición, se revierte', () async {
      await ds.addResumenDiario(cierre('2026-10-06', 10));
      final id = cierreDe('2026-10-06')!.id;
      servidor.respuesta = '{"status":"error","message":"falló"}';
      await expectLater(ds.updateResumenDiario(cierre('2026-10-06', 99).copyWith(id: id)), throwsA(isA<StateError>()));
      expect(cierreDe('2026-10-06')?.totalUsd, 10);
    });
  });

  group('C5 · un cierre no pisa otro', () {
    test('un segundo cierre del mismo día se rechaza (no se sobrescribe)', () async {
      await ds.addResumenDiario(cierre('2026-10-06', 10));
      await expectLater(ds.addResumenDiario(cierre('2026-10-06', 99)), throwsA(isA<ArgumentError>()));
      expect(cierreDe('2026-10-06')?.totalUsd, 10);
    });

    test('el mismo día en otra organización es un cierre distinto', () async {
      await ds.addResumenDiario(cierre('2026-10-06', 10));
      ds.setCurrentOrganizacion(orgB);
      await ds.addResumenDiario(cierre('2026-10-06', 20));
      ds.setCurrentOrganizacion(orgA);
      expect(cierreDe('2026-10-06')?.totalUsd, 10);
    });

    test('editar conserva fecha y organización aunque se envíe otra fecha', () async {
      ds.setCurrentOrganizacion(orgB);
      await ds.addResumenDiario(cierre('2026-10-06', 20));
      final id = cierreDe('2026-10-06')!.id;
      await ds.updateResumenDiario(cierre('2026-12-31', 25).copyWith(id: id));
      final editado = cierreDe('2026-10-06')!;
      expect(editado.totalUsd, 25);
      expect(editado.organizacionId, orgB);
    });

    test('editar un cierre inexistente falla en vez de decir "actualizado"', () async {
      await expectLater(
        ds.updateResumenDiario(cierre('2026-01-01', 5).copyWith(id: 'rd00000099')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('lectura de la hoja', () {
    test('formato con columna id', () {
      final r = ResumenDiario.fromRow(['rd00000007', '2026-10-06', '3', '100,50', '10', '36,5', '0', '0', '0', 'org-x']);
      expect(r.id, 'rd00000007');
      expect(r.fechaIso, '2026-10-06');
      expect(r.nroVentas, 3);
      expect(r.totalUsd, 10);
      expect(r.organizacionId, 'org-x');
    });

    test('formato anterior, sin columna id (hoja todavía no migrada)', () {
      final r = ResumenDiario.fromRow(['2026-04-03', '0', '0,00', '0,00', 'SIN DATOS', 'SIN DATOS', '0,00', '0,00', 'org-x']);
      expect(r.id, isEmpty);
      expect(r.fechaIso, '2026-04-03');
      expect(r.organizacionId, 'org-x');
    });
  });

  group('validación del formulario', () {
    ({ResumenDiario? resumen, String? error}) construir({String fecha = '2026-10-06', String bcv = '36,5', String ventas = '3'}) =>
        ReportingCubit.construirCierre(
          fecha: fecha,
          nroVentas: ventas,
          totalBs: '',
          totalUsd: '10.5',
          tasaBcv: bcv,
          tasaUsd: '',
          usdComprados: '',
          usdVendidos: '',
        );

    test('acepta coma decimal y campos vacíos como 0', () {
      final r = construir().resumen!;
      expect(r.tasaBcv, 36.5);
      expect(r.totalBs, 0);
      expect(r.nroVentas, 3);
    });

    test('una fecha inválida no se convierte en "hoy"', () {
      expect(construir(fecha: '6/10/2026').error, contains('Fecha inválida'));
      expect(construir(fecha: '').error, contains('Fecha inválida'));
    });

    test('una tasa mal escrita no se reemplaza por una inventada', () {
      expect(construir(bcv: '1.000,50').error, contains('Tasa BCV'));
      expect(construir(bcv: '-1').error, contains('negativo'));
      expect(construir(ventas: '2.5').error, contains('Nro. Ventas'));
    });
  });
}
