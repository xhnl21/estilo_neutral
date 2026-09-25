import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/features/credits/credits.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';

class _FakeSheetsDataService extends SheetsDataService {
  _FakeSheetsDataService() : super(spreadsheetId: 'test_sheet');

  BatchTransaction? lastExecutedTransaction;
  bool shouldFailBatch = false;
  String? failOnOperationId;

  @override
  String get nextAbonoId => 'ab00000099';

  @override
  TasaRegistro? tasaBcvVigente(String moneda) => TasaRegistro(
        id: 't00000001',
        fecha: DateTime.now(),
        moneda: 'USD',
        valor: 474.0,
        fuente: 'bcv',
      );

  @override
  Future<BatchTransactionResult> executeBatchTransaction(BatchTransaction transaction) async {
    lastExecutedTransaction = transaction;

    if (shouldFailBatch) {
      return BatchTransactionResult.failure(
        transactionId: transaction.transactionId,
        errorMessage: 'Fallo simulado en el servidor Apps Script',
      );
    }

    if (failOnOperationId != null) {
      return BatchTransactionResult.failure(
        transactionId: transaction.transactionId,
        errorMessage: 'Error en paso $failOnOperationId: Transacción revertida',
      );
    }

    return BatchTransactionResult(
      status: 'success',
      transactionId: transaction.transactionId,
      operationsCount: transaction.operations.length,
    );
  }

  @override
  Future<void> fetchAllSheets({bool silent = false}) async {}
}

void main() {
  group('Credits Application Tests (T09 - T13)', () {
    late _FakeSheetsDataService fakeDataService;
    late SheetsCreditsDataSource dataSource;
    late ClientCreditRepositoryImpl repository;

    setUp(() {
      fakeDataService = _FakeSheetsDataService();
      dataSource = SheetsCreditsDataSource(dataService: fakeDataService);
      // Limpiar y fijar un crédito disponible de prueba
      dataSource.setCredits([
        ClientCredit(
          id: CreditId('cr00000001'),
          clienteId: 'c00000001',
          fecha: DateTime(2026, 4, 1),
          montoUsd: CreditAmount(100.0),
          origenVentaId: 'v00000002',
          organizacionId: 'org1',
          saldoUsd: 100.0,
          usuarioEmail: 'test@antigravity.io',
        ),
      ]);
      repository = ClientCreditRepositoryImpl(dataSource: dataSource);
    });

    // T09. PreviewApplyCredit devuelve montos correctos sin persistir
    test('T09: PreviewApplyCredit calcula montos y saldo restante sin mutar estado', () async {
      final useCase = PreviewApplyCredit(repository: repository);
      final preview = await useCase(
        clienteId: 'c00000001',
        ventaDestinoId: 'v00000005',
        deudaVenta: 60.0,
      );

      expect(preview.montoAplicable, 60.0);
      expect(preview.saldoRestante, 40.0);
      expect(preview.deudaRestante, 0.0);
      expect(preview.creditosConsumidos.length, 1);
      expect(preview.advertencias.isNotEmpty, isTrue);

      // Verificar que el repositorio y datasource NO cambiaron
      final currentCredits = await repository.getAvailableCredits('c00000001');
      expect(currentCredits.first.saldoUsd, 100.0);
      expect(currentCredits.first.isAvailable, isTrue);
      expect(fakeDataService.lastExecutedTransaction, isNull);
    });

    // T10. ApplyClientCredit éxito total -> batch atómico con operaciones
    test('T10: ApplyClientCredit ejecuta con éxito las operaciones atómicas del lote', () async {
      final useCase = ApplyClientCredit(repository: repository);
      final result = await useCase.execute(
        clienteId: 'c00000001',
        targetVentaId: 'v00000005',
        deudaVenta: 100.0,
        userEmail: 'admin@antigravity.io',
      );

      expect(result.isSuccess, isTrue);
      expect(result.montoAplicado, 100.0);
      expect(result.saldoRestante, 0.0);
      expect(result.deudaRestante, 0.0);

      // Verificar que se envió la transacción por lote
      final tx = fakeDataService.lastExecutedTransaction;
      expect(tx, isNotNull);
      expect(tx!.operations.length, greaterThanOrEqualTo(3));

      // Op 1: abono con mp00000009
      final abonoOp = tx.operations.firstWhere((o) => o.sheet == 'abonos');
      expect(abonoOp.data!['metodo_pago'], 'mp00000009');
      expect(abonoOp.data!['monto'], 100.0);

      // Op 2: creditos_clientes APLICADO
      final creditOp = tx.operations.firstWhere((o) => o.sheet == 'creditos_clientes');
      expect(creditOp.data!['estado'], 'APLICADO');

      // Op 3: audit_log con SHA-256
      final auditOp = tx.operations.firstWhere((o) => o.sheet == 'audit_log');
      expect(auditOp.data!['norma'], contains('ISO 8000'));
      expect(auditOp.data!['hash_evidencia'], isNotNull);
    });

    // T11. ApplyClientCredit falla en op_abono -> rollback total (0 cambios)
    test('T11: Falla en lote causa rechazo y 0 cambios en el estado local', () async {
      fakeDataService.shouldFailBatch = true;
      final useCase = ApplyClientCredit(repository: repository);

      final result = await useCase.execute(
        clienteId: 'c00000001',
        targetVentaId: 'v00000005',
        deudaVenta: 100.0,
        userEmail: 'admin@antigravity.io',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, isNotNull);

      // El crédito permanece DISPONIBLE con su saldo íntegro
      final credits = await repository.getAvailableCredits('c00000001');
      expect(credits.length, 1);
      expect(credits.first.saldoUsd, 100.0);
      expect(credits.first.isAvailable, isTrue);
    });

    // T12. ApplyClientCredit con falla en paso consumir créditos
    test('T12: Simulación de falla en servidor revierte la aplicación', () async {
      fakeDataService.failOnOperationId = 'op_consumir_creditos';
      final useCase = ApplyClientCredit(repository: repository);

      final result = await useCase.execute(
        clienteId: 'c00000001',
        targetVentaId: 'v00000005',
        deudaVenta: 50.0,
        userEmail: 'admin@antigravity.io',
      );

      expect(result.isSuccess, isFalse);
      final credits = await repository.getAvailableCredits('c00000001');
      expect(credits.first.saldoUsd, 100.0);
    });

    // T13. ApplyClientCredit con falla en paso de auditoría forense
    test('T13: Falla en auditoría no persiste cambios parciales', () async {
      fakeDataService.failOnOperationId = 'op_audit_log';
      final useCase = ApplyClientCredit(repository: repository);

      final result = await useCase.execute(
        clienteId: 'c00000001',
        targetVentaId: 'v00000005',
        deudaVenta: 100.0,
        userEmail: 'admin@antigravity.io',
      );

      expect(result.isSuccess, isFalse);
      final credits = await repository.getAvailableCredits('c00000001');
      expect(credits.first.isAvailable, isTrue);
    });
  });
}
