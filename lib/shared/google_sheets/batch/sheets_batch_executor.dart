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
          sinRespuesta: true,
        );
      }

      return BatchTransactionResult.fromMap(res.data!);
    } catch (e) {
      return BatchTransactionResult.failure(
        transactionId: transaction.transactionId,
        errorMessage: 'Excepción durante la ejecución del lote atómico: $e',
        sinRespuesta: true,
      );
    }
  }

  /// Construye un lote atómico estándar para el registro de una venta completa con sus ítems,
  /// deducción de inventario, actualización de deuda del cliente, abono inicial y auditoría.
  static BatchTransaction buildVentaBatch({
    required Venta venta,
    required List<VentaItem> items,
    required Map<String, int> unidadesVendidas, // productoId -> unidades
    required double deudaAgregadaCliente,
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

    // 3. Descontar stock: se resta sobre el valor que tenga Sheets, no sobre
    // el que vio este teléfono (otro dispositivo pudo vender en el ínterin).
    unidadesVendidas.forEach((productoId, unidades) {
      operations.add(BatchOperation.increment(
        sheet: 'inventario',
        id: productoId,
        field: 'cantidad',
        delta: -unidades,
        min: 0,
      ));
    });

    // 4. Si queda saldo pendiente, sumarlo a la deuda del cliente
    if (deudaAgregadaCliente > 0) {
      operations.add(BatchOperation.increment(
        sheet: 'clientes',
        id: venta.clienteId,
        field: 'saldo_deuda_usd',
        delta: deudaAgregadaCliente,
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
