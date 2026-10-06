import 'package:equatable/equatable.dart';

/// Operación individual dentro de un lote transaccional.
class BatchOperation extends Equatable {
  final String sheet;
  final String action;
  final Map<String, dynamic>? data;
  final List<Map<String, dynamic>>? dataList;
  final String? id;
  final String? field;
  final dynamic newValue;

  /// Solo para `increment`: lo que se suma al valor actual de la celda, y el
  /// mínimo en que se corta el resultado.
  final num? delta;
  final num? min;

  const BatchOperation({
    required this.sheet,
    required this.action,
    this.data,
    this.dataList,
    this.id,
    this.field,
    this.newValue,
    this.delta,
    this.min,
  });

  factory BatchOperation.create({
    required String sheet,
    required Map<String, dynamic> data,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'create',
      data: data,
    );
  }

  factory BatchOperation.batchCreate({
    required String sheet,
    required List<Map<String, dynamic>> dataList,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'batch_create',
      dataList: dataList,
    );
  }

  factory BatchOperation.update({
    required String sheet,
    required String id,
    required Map<String, dynamic> data,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'update',
      id: id,
      data: data,
    );
  }

  factory BatchOperation.updateCell({
    required String sheet,
    required String id,
    required String field,
    required dynamic newValue,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'update_cell',
      id: id,
      field: field,
      newValue: newValue,
    );
  }

  /// Suma [delta] al valor que la celda tenga EN EL SERVIDOR al aplicar el
  /// lote (no a un valor calculado en el teléfono), así dos dispositivos que
  /// descuentan stock o deuda a la vez no se pisan. El valor resultante
  /// vuelve en `BatchTransactionResult.results` (`value`).
  factory BatchOperation.increment({
    required String sheet,
    required String id,
    required String field,
    required num delta,
    num? min,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'increment',
      id: id,
      field: field,
      delta: delta,
      min: min,
    );
  }

  factory BatchOperation.delete({
    required String sheet,
    required String id,
  }) {
    return BatchOperation(
      sheet: sheet,
      action: 'delete',
      id: id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sheet': sheet,
      'action': action,
      if (data != null) 'data': data,
      if (dataList != null) 'dataList': dataList,
      if (id != null) 'id': id,
      if (field != null) 'field': field,
      if (newValue != null) 'newValue': newValue,
      if (delta != null) 'delta': delta,
      if (min != null) 'min': min,
    };
  }

  factory BatchOperation.fromMap(Map<String, dynamic> map) {
    return BatchOperation(
      sheet: map['sheet'] as String? ?? '',
      action: map['action'] as String? ?? '',
      data: map['data'] != null ? Map<String, dynamic>.from(map['data'] as Map) : null,
      dataList: map['dataList'] != null
          ? (map['dataList'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      id: map['id'] as String?,
      field: map['field'] as String?,
      newValue: map['newValue'],
      delta: map['delta'] as num?,
      min: map['min'] as num?,
    );
  }

  @override
  List<Object?> get props => [sheet, action, data, dataList, id, field, newValue, delta, min];
}

/// Transacción compuesta por una lista de operaciones atómicas (All-or-Nothing).
class BatchTransaction extends Equatable {
  final String transactionId;
  final List<BatchOperation> operations;
  final DateTime timestamp;

  BatchTransaction({
    String? transactionId,
    required this.operations,
    DateTime? timestamp,
  })  : transactionId = transactionId ??
            'tx_${DateTime.now().millisecondsSinceEpoch}_${operations.length}',
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'action': 'batch',
      'transactionId': transactionId,
      'timestamp': timestamp.toIso8601String(),
      'operations': operations.map((op) => op.toMap()).toList(),
    };
  }

  @override
  List<Object?> get props => [transactionId, operations, timestamp];
}

/// Resultado retornado por el backend tras intentar ejecutar el lote atómico.
class BatchTransactionResult extends Equatable {
  final String status;
  final String transactionId;
  final String? message;
  final int operationsCount;
  final Map<String, dynamic> generatedIds;
  final List<Map<String, dynamic>> results;

  /// `true` si no se obtuvo respuesta legible del servidor (timeout, error de
  /// red, eco ilegible): no se sabe si el lote se aplicó o no.
  final bool sinRespuesta;

  const BatchTransactionResult({
    required this.status,
    required this.transactionId,
    this.message,
    this.operationsCount = 0,
    this.generatedIds = const {},
    this.results = const [],
    this.sinRespuesta = false,
  });

  bool get isSuccess => status == 'success';

  /// Valor que dejó en la celda la operación `increment` sobre [sheet]/[id],
  /// o `null` si el servidor no lo informó.
  num? valorIncrementado(String sheet, String id) {
    for (final r in results) {
      if (r['action'] == 'increment' && r['sheet'] == sheet && r['id'] == id) {
        final v = r['value'];
        if (v is num) return v;
        return num.tryParse('$v');
      }
    }
    return null;
  }

  factory BatchTransactionResult.fromMap(Map<String, dynamic> map) {
    return BatchTransactionResult(
      status: map['status'] as String? ?? 'error',
      transactionId: map['transactionId'] as String? ?? '',
      message: map['message'] as String?,
      operationsCount: map['operationsCount'] as int? ?? 0,
      generatedIds: map['generatedIds'] != null
          ? Map<String, dynamic>.from(map['generatedIds'] as Map)
          : const {},
      results: map['results'] != null
          ? (map['results'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const [],
    );
  }

  factory BatchTransactionResult.failure({
    required String transactionId,
    required String errorMessage,
    bool sinRespuesta = false,
  }) {
    return BatchTransactionResult(
      status: 'error',
      transactionId: transactionId,
      message: errorMessage,
      sinRespuesta: sinRespuesta,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transactionId,
        message,
        sinRespuesta,
        operationsCount,
        generatedIds,
        results,
      ];
}
