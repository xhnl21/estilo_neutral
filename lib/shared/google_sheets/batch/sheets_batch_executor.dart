import '../../../models/models.dart';

/// Ejecutor de transacciones atómicas por lote contra Google Apps Script.
class SheetsBatchExecutor {
  final Future<({bool huboRedirect, Map<String, dynamic>? data})> Function(
    Map<String, dynamic> payload,
  ) postJson;

  const SheetsBatchExecutor({required this.postJson});

  /// Ejecuta una transacción por lotes en Google Apps Script con semántica All-or-Nothing.
  Future<BatchTransactionResult> execute(BatchTransaction transaction) async {
    try {
      final payload = transaction.toMap();
      final res = await postJson(payload);

      if (res.data == null) {
        return BatchTransactionResult.failure(
          transactionId: transaction.transactionId,
          errorMessage:
              'No se recibió respuesta válida del servidor (posible error de red o timeout)',
        );
      }

      return BatchTransactionResult.fromMap(res.data!);
    } catch (e) {
      return BatchTransactionResult.failure(
        transactionId: transaction.transactionId,
        errorMessage: 'Excepción durante la ejecución del lote atómico: $e',
      );
    }
  }

  /// Construye un lote atómico estándar para el registro de una venta completa con sus ítems,
  /// deducción de inventario, actualización de deuda del cliente, abono inicial y auditoría.
  static BatchTransaction buildVentaBatch({
    required Venta venta,
    required List<VentaItem> items,
    required Map<String, int> stockUpdates, // productoId -> nuevoStock
    required double? nuevoSaldoDeudaCliente,
    required Abono? abonoInicial,
    required AuditLog auditLog,
    String? transactionId,
  }) {
    final operations = <BatchOperation>[];

    // 1. Crear cabecera de venta
    operations.add(BatchOperation.create(
      sheet: 'ventas',
      data: venta.toMap(),
    ));

    // 2. Crear ítems en lote asociados a la venta recién creada
    operations.add(BatchOperation.batchCreate(
      sheet: 'venta_items',
      dataList: items.map((it) {
        final map = it.toMap();
        // Permite que Apps Script enlace el ítem al ID generado por la operación previa
        map['venta_id'] = r'$last_id';
        return map;
      }).toList(),
    ));

    // 3. Descontar stock en inventario para cada producto
    stockUpdates.forEach((productoId, nuevoStock) {
      operations.add(BatchOperation.updateCell(
        sheet: 'inventario',
        id: productoId,
        field: 'cantidad',
        newValue: nuevoStock,
      ));
    });

    // 4. Si hay saldo pendiente, actualizar la deuda del cliente
    if (nuevoSaldoDeudaCliente != null) {
      operations.add(BatchOperation.updateCell(
        sheet: 'clientes',
        id: venta.clienteId,
        field: 'saldo_deuda_usd',
        newValue: nuevoSaldoDeudaCliente,
      ));
    }

    // 5. Si hay abono inicial, crearlo en la hoja abonos
    if (abonoInicial != null) {
      final abonoMap = abonoInicial.toMap();
      abonoMap['venta_id'] = r'$last_id';
      operations.add(BatchOperation.create(
        sheet: 'abonos',
        data: abonoMap,
      ));
    }

    // 6. Asentar en audit_log
    operations.add(BatchOperation.create(
      sheet: 'audit_log',
      data: auditLog.toMap(),
    ));

    return BatchTransaction(
      transactionId: transactionId,
      operations: operations,
    );
  }
}
