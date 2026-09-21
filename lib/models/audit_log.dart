/// Modelo de entidad AuditLog mapeado desde la hoja "audit_log"
/// Entidad de SOLO LECTURA (Trazabilidad y no-repudio ISO/IEC 27001 §12.4)
class AuditLog {
  /// Columna A: Timestamp ISO 8601 con zona horaria
  final DateTime timestampIso8601;

  /// Columna B: Usuario o agente que ejecutó el cambio
  final String usuario;

  /// Columna C: Hoja afectada
  final String hoja;

  /// Columna D: Celda o rango modificado
  final String celda;

  /// Columna E: Valor anterior antes de la acción
  final String valorAnterior;

  /// Columna F: Nuevo valor aplicado
  final String valorNuevo;

  /// Columna G: Tipo de acción ejecutada
  final String accion;

  /// Columna H: Norma internacional de cumplimiento
  final String normaAplicada;

  /// Columna I: Observaciones forenses
  final String observaciones;

  /// Columna J: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const AuditLog({
    required this.timestampIso8601,
    required this.usuario,
    required this.hoja,
    required this.celda,
    required this.valorAnterior,
    required this.valorNuevo,
    required this.accion,
    required this.normaAplicada,
    required this.observaciones,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory AuditLog.fromRow(List<dynamic> row) {
    return AuditLog(
      timestampIso8601: row.isNotEmpty ? DateTime.tryParse(row[0].toString()) ?? DateTime.now() : DateTime.now(),
      usuario: row.length > 1 ? row[1].toString() : '',
      hoja: row.length > 2 ? row[2].toString() : '',
      celda: row.length > 3 ? row[3].toString() : '',
      valorAnterior: row.length > 4 ? row[4].toString() : '',
      valorNuevo: row.length > 5 ? row[5].toString() : '',
      accion: row.length > 6 ? row[6].toString() : '',
      normaAplicada: row.length > 7 ? row[7].toString() : '',
      observaciones: row.length > 8 ? row[8].toString() : '',
      organizacionId: row.length > 9 && row[9].toString().trim().isNotEmpty
          ? row[9].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp_iso8601': timestampIso8601.toIso8601String(),
      'usuario': usuario,
      'hoja': hoja,
      'celda': celda,
      'valor_anterior': valorAnterior,
      'valor_nuevo': valorNuevo,
      'accion': accion,
      'norma_aplicada': normaAplicada,
      'observaciones': observaciones,
      'organizacion_id': organizacionId,
    };
  }
}
