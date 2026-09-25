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

  const BatchOperation({
    required this.sheet,
    required this.action,
    this.data,
    this.dataList,
    this.id,
    this.field,
    this.newValue,
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
    );
  }

  @override
  List<Object?> get props => [sheet, action, data, dataList, id, field, newValue];
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

  const BatchTransactionResult({
    required this.status,
    required this.transactionId,
    this.message,
    this.operationsCount = 0,
    this.generatedIds = const {},
    this.results = const [],
  });

  bool get isSuccess => status == 'success';

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
  }) {
    return BatchTransactionResult(
      status: 'error',
      transactionId: transactionId,
      message: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transactionId,
        message,
        operationsCount,
        generatedIds,
        results,
      ];
}
