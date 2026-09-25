import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/credits/credits.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

class _MockDataService extends SheetsDataService {
  _MockDataService() : super(spreadsheetId: 'test');
  @override
  String get nextAbonoId => 'ab00000001';
}

void main() {
  group('Credits UI Tests (T14 - T16)', () {
    // T14. ApplyCreditButton deshabilitado si saldo <= 0
    testWidgets('T14: ApplyCreditButton deshabilitado si applicableAmount <= 0',
        (tester) async {
      var pressed = false;

      // Monto cero: botón deshabilitado
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApplyCreditButton(
              applicableAmount: 0.0,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final buttonZero = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(buttonZero.onPressed, isNull);

      // Con monto positivo: botón habilitado
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApplyCreditButton(
              applicableAmount: 50.0,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      final buttonActive = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(buttonActive.onPressed, isNotNull);

      await tester.tap(find.byType(OutlinedButton));
      expect(pressed, isTrue);
    });

    // T15. ApplyCreditSheet muestra 4 cifras con tabularFigures
    testWidgets('T15: ApplyCreditSheet muestra las 4 cifras requeridas',
        (tester) async {
      final ds = _MockDataService();
      final src = SheetsCreditsDataSource(dataService: ds);
      final repo = ClientCreditRepositoryImpl(dataSource: src);
      final cubit = ApplyCreditCubit(repository: repo, dataService: ds);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const ApplyCreditSheet(
                clienteId: 'c00000002',
                clienteNombre: 'Neyza Chourio',
                ventaId: 'v00000005',
                deudaVenta: 100.0,
                totalCreditoDisponible: 100.0,
                origenVentaId: 'v00000002',
                userEmail: 'agent@antigravity.io',
              ),
            ),
          ),
        ),
      );

      // Cifras esperadas
      expect(find.text('Saldo a favor disponible'), findsOneWidget);
      expect(find.text('Deuda de la factura #v00000005'), findsOneWidget);
      expect(find.text('Se aplicará'), findsOneWidget);
      expect(find.text('Saldo restante después'), findsOneWidget);
      expect(find.text('Deuda restante después'), findsOneWidget);

      // Mensaje de compensación claro (sin dinero nuevo)
      expect(
        find.textContaining('No entra dinero nuevo. Se reutiliza el pago'),
        findsOneWidget,
      );
    });

    // T16. Semantics label correcto en cada cifra
    testWidgets('T16: CreditSummaryRow expone Semantics accesible con texto verbalizado',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreditSummaryRow(
              label: 'Saldo a favor disponible',
              amount: 100.0,
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Saldo a favor disponible: 100.00 dólares'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
