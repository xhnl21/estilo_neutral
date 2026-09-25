import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/models.dart';
import 'package:estilo_neutral/shared/google_sheets/batch/sheets_batch_executor.dart';
import 'package:estilo_neutral/shared/google_sheets/sheets_data_service.dart';
import '../test_sheets_config.dart';

class _FakeBatchHttpClientAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responsePayload;

  _FakeBatchHttpClientAdapter({
    required this.responsePayload,
  });

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = utf8.encode(jsonEncode(responsePayload));
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  group('SheetsBatchExecutor Unit Tests', () {
    test('execute retorna BatchTransactionResult exitoso cuando el servidor responde 200 OK', () async {
      final executor = SheetsBatchExecutor(
        postJson: (payload) async {
          expect(payload['action'], 'batch');
          expect(payload['transactionId'], 'tx_test');
          return (
            huboRedirect: false,
            data: <String, dynamic>{
              'status': 'success',
              'transactionId': 'tx_test',
              'message': 'Lote ejecutado con éxito',
              'operationsCount': 2,
              'generatedIds': {'ventas': 'v00000099'},
            }
          );
        },
      );

      final tx = BatchTransaction(
        transactionId: 'tx_test',
        operations: const [
          BatchOperation(
            sheet: 'ventas',
            action: 'create',
            data: {'cliente_id': 'c001'},
          ),
        ],
      );

      final result = await executor.execute(tx);
      expect(result.isSuccess, isTrue);
      expect(result.transactionId, 'tx_test');
      expect(result.generatedIds['ventas'], 'v00000099');
    });

    test('execute retorna BatchTransactionResult con error cuando el servidor aborta y hace rollback', () async {
      final executor = SheetsBatchExecutor(
        postJson: (payload) async {
          return (
            huboRedirect: false,
            data: <String, dynamic>{
              'status': 'error',
              'transactionId': 'tx_fail',
              'message': 'Transacción abortada (Rollback ejecutado): Stock insuficiente',
            }
          );
        },
      );

      final tx = BatchTransaction(
        transactionId: 'tx_fail',
        operations: const [
          BatchOperation(
            sheet: 'ventas',
            action: 'create',
            data: {'cliente_id': 'c001'},
          ),
        ],
      );

      final result = await executor.execute(tx);
      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Rollback ejecutado'));
    });

    test('buildVentaBatch genera las operaciones en el orden correcto', () {
      final venta = Venta(
        id: 'v_temp',
        fecha: DateTime.now(),
        clienteId: 'c001',
        tasaBcv: 450.0,
        tasaUsd: 450.0,
        metodoPagoId: 'mp01',
        comisionPagoMovilBs: 0.0,
        montoBs: 45000.0,
        montoUsd: 100.0,
        abonoUsd: 50.0,
        deudaUsd: 50.0,
        totalPagarUsd: 100.0,
        validacion: 'OK',
        estado: EstadoVenta.pendiente,
        organizacionId: 'org1',
      );

      final items = [
        const VentaItem(
          id: 'vi_temp',
          ventaId: 'v_temp',
          itemId: 'p001',
          cantidad: 2,
          precioUsd: 50.0,
          subtotalUsd: 100.0,
        ),
      ];

      final audit = AuditLog(
        timestampIso8601: DateTime.now(),
        usuario: 'test',
        hoja: 'ventas',
        celda: 'A1',
        valorAnterior: 'null',
        valorNuevo: 'v_temp',
        accion: 'creacion_venta_atomica',
        normaAplicada: 'ISO 8000',
        observaciones: 'test audit',
        organizacionId: 'org1',
      );

      final tx = SheetsBatchExecutor.buildVentaBatch(
        venta: venta,
        items: items,
        stockUpdates: {'p001': 8},
        nuevoSaldoDeudaCliente: 50.0,
        abonoInicial: Abono(
          id: 'ab_temp',
          ventaId: 'v_temp',
          fecha: DateTime.now(),
          monto: 50.0,
          metodoPagoId: 'mp01',
          tasaId: 't001',
        ),
        auditLog: audit,
        transactionId: 'tx_build_test',
      );

      expect(tx.operations.length, 6);
      expect(tx.operations[0].sheet, 'ventas');
      expect(tx.operations[0].action, 'create');
      expect(tx.operations[1].sheet, 'venta_items');
      expect(tx.operations[1].action, 'batch_create');
      expect(tx.operations[2].sheet, 'inventario');
      expect(tx.operations[2].action, 'update_cell');
      expect(tx.operations[3].sheet, 'clientes');
      expect(tx.operations[3].action, 'update_cell');
      expect(tx.operations[4].sheet, 'abonos');
      expect(tx.operations[4].action, 'create');
      expect(tx.operations[5].sheet, 'audit_log');
      expect(tx.operations[5].action, 'create');
    });
  });

  group('SheetsDataService Atomic Batch Integration', () {
    test('addVentaAtomica preserva memoria intacta si el servidor responde error (All-or-Nothing)', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeBatchHttpClientAdapter(
        responsePayload: const {
          'status': 'error',
          'message': 'Error simulado de servidor en transacción',
        },
      );

      final service = SheetsDataService(
        spreadsheetId: testSpreadsheetId,
        appsScriptUrl: testAppsScriptUrl,
        dio: dio,
      );

      await service.initialize();
      service.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');

      final initialVentasCount = service.ventas.length;
      final initialCliente = service.clientes.first;
      final initialStock = service.productos.first.cantidad;

      final success = await service.addVentaAtomica(
        clienteId: initialCliente.id,
        items: [(productoId: service.productos.first.id, cantidad: 1, precioUsd: 10.0)],
        metodoPagoId: 'Efectivo USD',
        abonoUsd: 5.0,
      );

      expect(success, isFalse);
      // Memoria local NO fue modificada
      expect(service.ventas.length, initialVentasCount);
      expect(service.productos.first.cantidad, initialStock);
    });

    test('addVentaAtomica actualiza memoria local si el servidor responde éxito', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeBatchHttpClientAdapter(
        responsePayload: const {
          'status': 'success',
          'transactionId': 'tx_ok_123',
          'generatedIds': {'ventas': 'v00000999'},
        },
      );

      final service = SheetsDataService(
        spreadsheetId: testSpreadsheetId,
        appsScriptUrl: testAppsScriptUrl,
        dio: dio,
      );

      await service.initialize();
      service.setCurrentOrganizacion('67774411-6aa1-4aa3-a4b2-d3fc6913b768');

      final initialVentasCount = service.ventas.length;
      final prod = service.productos.first;
      final initialStock = prod.cantidad;

      final success = await service.addVentaAtomica(
        clienteId: service.clientes.first.id,
        items: [(productoId: prod.id, cantidad: 2, precioUsd: 20.0)],
        metodoPagoId: 'Efectivo USD',
        abonoUsd: 20.0,
      );

      expect(success, isTrue);
      // Memoria local fue actualizada con el ID generado del servidor
      expect(service.ventas.length, initialVentasCount + 1);
      expect(service.ventas.first.id, 'v00000999');
      expect(service.productos.firstWhere((p) => p.id == prod.id).cantidad, initialStock - 2);
    });
  });
}
