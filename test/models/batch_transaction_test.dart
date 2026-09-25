import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/batch_transaction.dart';

void main() {
  group('BatchOperation Tests', () {
    test('BatchOperation.create serializa correctamente', () {
      final op = BatchOperation.create(
        sheet: 'ventas',
        data: const {'id': 'v001', 'total': 100.0},
      );

      expect(op.sheet, 'ventas');
      expect(op.action, 'create');
      expect(op.data?['id'], 'v001');

      final map = op.toMap();
      expect(map['sheet'], 'ventas');
      expect(map['action'], 'create');
      expect(map['data']['total'], 100.0);

      final fromMap = BatchOperation.fromMap(map);
      expect(fromMap, equals(op));
    });

    test('BatchOperation.batchCreate serializa lista correctamente', () {
      final op = BatchOperation.batchCreate(
        sheet: 'venta_items',
        dataList: const [
          {'item_id': 'p001', 'cantidad': 2},
          {'item_id': 'p002', 'cantidad': 1},
        ],
      );

      expect(op.action, 'batch_create');
      expect(op.dataList?.length, 2);

      final map = op.toMap();
      final fromMap = BatchOperation.fromMap(map);
      expect(fromMap, equals(op));
    });

    test('BatchOperation.updateCell serializa campos correctamente', () {
      final op = BatchOperation.updateCell(
        sheet: 'inventario',
        id: 'p001',
        field: 'cantidad',
        newValue: 8,
      );

      expect(op.action, 'update_cell');
      expect(op.id, 'p001');
      expect(op.field, 'cantidad');
      expect(op.newValue, 8);

      final map = op.toMap();
      final fromMap = BatchOperation.fromMap(map);
      expect(fromMap, equals(op));
    });

    test('BatchOperation.delete serializa id correctamente', () {
      final op = BatchOperation.delete(
        sheet: 'ventas',
        id: 'v001',
      );

      expect(op.action, 'delete');
      expect(op.id, 'v001');

      final map = op.toMap();
      final fromMap = BatchOperation.fromMap(map);
      expect(fromMap, equals(op));
    });
  });

  group('BatchTransaction Tests', () {
    test('BatchTransaction genera toMap con action "batch" y operaciones', () {
      final tx = BatchTransaction(
        transactionId: 'tx_test_123',
        operations: [
          BatchOperation.create(sheet: 'ventas', data: const {'id': 'v001'}),
          BatchOperation.updateCell(
            sheet: 'inventario',
            id: 'p001',
            field: 'cantidad',
            newValue: 5,
          ),
        ],
      );

      expect(tx.transactionId, 'tx_test_123');
      expect(tx.operations.length, 2);

      final map = tx.toMap();
      expect(map['action'], 'batch');
      expect(map['transactionId'], 'tx_test_123');
      expect((map['operations'] as List).length, 2);
    });
  });

  group('BatchTransactionResult Tests', () {
    test('BatchTransactionResult parsea respuesta exitosa', () {
      final json = {
        'status': 'success',
        'transactionId': 'tx_123',
        'message': 'Transacción atómica ejecutada con éxito',
        'operationsCount': 3,
        'generatedIds': {'ventas': 'v00000010'},
        'results': [
          {'opIndex': 0, 'action': 'create', 'id': 'v00000010'},
        ],
      };

      final result = BatchTransactionResult.fromMap(json);
      expect(result.isSuccess, isTrue);
      expect(result.transactionId, 'tx_123');
      expect(result.operationsCount, 3);
      expect(result.generatedIds['ventas'], 'v00000010');
      expect(result.results.length, 1);
    });

    test('BatchTransactionResult parsea error o usa factory failure', () {
      final fail = BatchTransactionResult.failure(
        transactionId: 'tx_fail_999',
        errorMessage: 'Rollback aplicado por fallo en validación de FK',
      );

      expect(fail.isSuccess, isFalse);
      expect(fail.status, 'error');
      expect(fail.transactionId, 'tx_fail_999');
      expect(fail.message, contains('Rollback aplicado'));
    });
  });
}
