import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/presentation/cubits/abono/abono_cubit.dart';
import 'package:estilo_neutral/presentation/cubits/abono/abono_state.dart';
import 'package:estilo_neutral/presentation/pages/ventas_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';
import '../test_servidor.dart';

/// Lecturas gviz fallan (datos de respaldo); el Apps Script responde éxito.
class _Servidor implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final gviz = o.uri.toString().contains('gviz');
    if (gviz) return lecturaSinDatos();
    return ResponseBody.fromBytes(
      utf8.encode('{"status":"success","transactionId":"tx"}'),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // v00000005: total 100, deuda 100.
  const ventaId = 'v00000005';
  late SheetsDataService ds;

  setUp(() async {
    ds = SheetsDataService(
      spreadsheetId: testSpreadsheetId,
      appsScriptUrl: testAppsScriptUrl,
      dio: Dio()..httpClientAdapter = _Servidor(),
    );
    await ds.initialize();
    ds.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');
  });

  group('AbonoCubit', () {
    test('valida el monto antes de enviar', () async {
      final cubit = AbonoCubit(dataService: ds, ventaId: ventaId);
      await cubit.registrar('abc');
      expect(cubit.state.errorMonto, isNotNull);
      await cubit.registrar('-5');
      expect(cubit.state.errorMonto, isNotNull);
      expect(ds.ventas.firstWhere((v) => v.id == ventaId).abonoUsd, 0);
      cubit.montoCambiado();
      expect(cubit.state.errorMonto, isNull);
      await cubit.close();
    });

    test('registra el abono con el método elegido y termina', () async {
      final cubit = AbonoCubit(dataService: ds, ventaId: ventaId);
      final otro = cubit.state.metodosPago.last.id;
      cubit.seleccionarMetodo(otro);

      await cubit.registrar('25,50');

      expect(cubit.state.status, AbonoStatus.terminado);
      expect(cubit.state.resultado, ResultadoAbono.registrado);
      expect(ds.abonos.first.metodoPagoId, otro);
      expect(cubit.state.venta!.deudaUsd, closeTo(74.5, 0.001));
      await cubit.close();
    });

    test('la deuda mostrada se actualiza si la venta cambia con el diálogo abierto', () async {
      final cubit = AbonoCubit(dataService: ds, ventaId: ventaId);
      expect(cubit.state.venta!.deudaUsd, 100);
      await ds.registrarAbono(ventaId, 40, metodoPagoId: ds.metodosPagoActivos.first.id);
      expect(cubit.state.venta!.deudaUsd, 60);
      await cubit.close();
    });
  });

  testWidgets('el diálogo registra el abono y se cierra', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: VentasPage(dataService: ds),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#$ventaId').first);
    await tester.pumpAndSettle();

    final abonar = find.textContaining('Abonar');
    expect(abonar, findsWidgets);
    await tester.tap(abonar.first);
    await tester.pumpAndSettle();
    expect(find.text('Abono a Venta #$ventaId'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Monto a Abonar (USD)'), '10');
    await tester.tap(find.text('Aplicar Abono'));
    await tester.pumpAndSettle();

    expect(find.text('Abono a Venta #$ventaId'), findsNothing);
    expect(find.text('Pago registrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
