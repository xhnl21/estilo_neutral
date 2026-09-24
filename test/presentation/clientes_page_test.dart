import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';

void main() {
  testWidgets('ClientesPage renders on narrow screen with large debt without RenderFlex overflow', (tester) async {
    // Set screen size matching physical Redmi Note 8 screen (approx 392 x 800)
    tester.view.physicalSize = const Size(392 * 2.8, 800 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // No se llama a service.initialize(): este test solo verifica el layout
    // con datos locales y no necesita (ni debe) tocar la hoja real — dentro
    // de un testWidgets, el HttpClient queda interceptado por
    // TestWidgetsFlutterBinding y la llamada de red cuelga hasta el timeout
    // de 10 minutos en vez de fallar rápido.
    final service = SheetsDataService(spreadsheetId: testSpreadsheetId, appsScriptUrl: testAppsScriptUrl);
    service.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');

    // Add a customer with large debt that previously caused the 29px RenderFlex overflow
    //
    // ClientesPage ya no confía en cliente.saldoDeudaUsd para mostrar la
    // deuda (ese campo puede desincronizarse) — calcula "deudaReal" a partir
    // de las facturas (ventas) del cliente. Por eso hace falta una Venta con
    // deuda pendiente, no solo poner saldoDeudaUsd en el modelo Cliente.
    //
    // addCliente()/addVenta() sincronizan en segundo plano con Apps Script
    // (sin esperarlo) — esos POST reales con dio necesitan correr en la zone
    // real de `runAsync`, si no, el Future nunca se resuelve dentro del zone
    // "fake async" de testWidgets() y pumpAndSettle() se cuelga esperándolo.
    await tester.runAsync(() async {
      await service.addCliente(
        Cliente(
          id: 'c99999999',
          nombre: 'Cliente Con Deuda Grande',
          telefono: '+584121234567',
          email: 'deuda@ejemplo.com',
          saldoDeudaUsd: 20000.00,
          fechaRegistro: DateTime(2026, 9, 14),
        ),
      );
      await service.addVenta(
        clienteId: 'c99999999',
        items: const [(productoId: 'p_fake', cantidad: 1, precioUsd: 20000.00)],
        metodoPagoId: 'mp_fake',
        abonoUsd: 0.0,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ClientesPage(dataService: service),
      ),
    );

    await tester.pumpAndSettle();

    // tester.takeException() es la API soportada por Flutter para revisar si
    // el árbol de widgets tiró un error (ej. un RenderFlex overflow) durante
    // el pump, sin que el test lo dé por fallido automáticamente. La versión
    // anterior reemplazaba `FlutterError.onError` a mano sin encadenar el
    // handler original — eso rompe el tracking interno de excepciones
    // pendientes de TestWidgetsFlutterBinding y hacía fallar el test con un
    // `_pendingExceptionDetails != null` ajeno al layout que se quería probar.
    final exception = tester.takeException();
    if (exception != null) {
      // ignore: avoid_print
      print('CAUGHT EXCEPTION:\n$exception');
    }
    expect(exception, isNull);
    expect(find.textContaining('Cliente Con Deuda Grande'), findsOneWidget);
    expect(find.text(r'$20000.00'), findsOneWidget);
  });
}
