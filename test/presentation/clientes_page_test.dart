import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/models/cliente.dart';
import 'package:estilo_neutral/presentation/pages/clientes_page.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

void main() {
  testWidgets('ClientesPage renders on narrow screen with large debt without RenderFlex overflow', (tester) async {
    // Set screen size matching physical Redmi Note 8 screen (approx 392 x 800)
    tester.view.physicalSize = const Size(392 * 2.8, 800 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = SheetsDataService();
    service.initialize();
    service.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');

    // Add a customer with large debt that previously caused the 29px RenderFlex overflow
    service.addCliente(
      Cliente(
        id: 'c99999999',
        nombre: 'Cliente Con Deuda Grande',
        telefono: '+584121234567',
        email: 'deuda@ejemplo.com',
        saldoDeudaUsd: 20000.00,
        fechaRegistro: DateTime(2026, 9, 14),
      ),
    );

    FlutterErrorDetails? errorDetails;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errorDetails = details;
    };
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ClientesPage(dataService: service),
      ),
    );

    await tester.pumpAndSettle();

    if (errorDetails != null) {
      // ignore: avoid_print
      print('CAUGHT DETAILS:\n$errorDetails');
    }
    expect(errorDetails, isNull);
    expect(find.textContaining('Cliente Con Deuda Grande'), findsOneWidget);
    expect(find.text(r'$20000.00'), findsOneWidget);
  });
}
