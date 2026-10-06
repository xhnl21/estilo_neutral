import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';

/// Lecturas gviz siempre fallan (quedan los datos de respaldo); el lote del
/// Apps Script responde [respuestaScript], o 500 si es `null` (sin respuesta).
class _Servidor implements HttpClientAdapter {
  String? respuestaScript = '{"status":"success","transactionId":"tx"}';
  int lecturasGviz = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final esGviz = o.uri.toString().contains('gviz');
    if (esGviz) lecturasGviz++;
    final body = esGviz ? null : respuestaScript;
    return ResponseBody.fromBytes(
      utf8.encode(body ?? 'error'),
      body == null ? 500 : 200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // v00000005: total 100, abonado 0, deuda 100 (cliente c00000002).
  const ventaId = 'v00000005';
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
    ds.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
  });

  double abonado() => ds.ventas.firstWhere((v) => v.id == ventaId).abonoUsd;
  int abonosDeLaVenta() => ds.abonos.where((a) => a.ventaId == ventaId).length;
  String metodo() => ds.metodosPagoActivos.first.id;

  test('lote rechazado: se revierte y al reintentar el abono no se duplica', () async {
    final saldoCliente = ds.clientes.firstWhere((c) => c.id == 'c00000002').saldoDeudaUsd;
    final abonosAntes = abonosDeLaVenta();

    servidor.respuestaScript = '{"status":"error","message":"Rollback ejecutado"}';
    final r1 = await ds.registrarAbono(ventaId, 20, metodoPagoId: metodo());

    expect(r1, ResultadoAbono.rechazado);
    expect(abonado(), 0);
    expect(abonosDeLaVenta(), abonosAntes);
    expect(ds.clientes.firstWhere((c) => c.id == 'c00000002').saldoDeudaUsd, saldoCliente);

    servidor.respuestaScript = '{"status":"success","transactionId":"tx"}';
    final r2 = await ds.registrarAbono(ventaId, 20, metodoPagoId: metodo());

    expect(r2, ResultadoAbono.registrado);
    expect(abonado(), 20); // no 40
    expect(abonosDeLaVenta(), abonosAntes + 1);
  });

  test('sin respuesta del servidor: se revierte y se releen los datos de Sheets', () async {
    final lecturasAntes = servidor.lecturasGviz;
    servidor.respuestaScript = null;

    final r = await ds.registrarAbono(ventaId, 20, metodoPagoId: metodo());

    expect(r, ResultadoAbono.sinConfirmar);
    expect(abonado(), 0);
    expect(servidor.lecturasGviz, greaterThan(lecturasAntes));
  });

  test('un sobrepago rechazado no deja un crédito a favor fantasma', () async {
    final creditosAntes = ds.creditosClientes.length;
    servidor.respuestaScript = '{"status":"error","message":"Rollback ejecutado"}';

    await ds.registrarAbono(ventaId, 150, metodoPagoId: metodo());

    expect(ds.creditosClientes.length, creditosAntes);
    expect(abonado(), 0);
  });

  test('el abono se ve en la app de inmediato, antes de la respuesta', () async {
    final pendiente = ds.registrarAbono(ventaId, 20, metodoPagoId: metodo());
    expect(abonado(), 20);
    expect(await pendiente, ResultadoAbono.registrado);
  });
}
