import 'fila_hoja.dart';

/// Modelo de entidad AuditLog mapeado desde la hoja "audit_log"
/// Entidad de SOLO LECTURA (Trazabilidad y no-repudio ISO/IEC 27001 §12.4)
class AuditLog {
  /// ID generado por el servidor (al00000001). Vacío si aún no se confirmó.
  final String id;

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
    this.id = '',
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
    final f = FilaHoja.leer(row, 'al');
    return AuditLog(
      id: f.id,
      timestampIso8601: DateTime.tryParse(f.texto(0)) ?? DateTime.now(),
      usuario: f.crudo(1),
      hoja: f.crudo(2),
      celda: f.crudo(3),
      valorAnterior: f.crudo(4),
      valorNuevo: f.crudo(5),
      accion: f.crudo(6),
      normaAplicada: f.crudo(7),
      observaciones: f.crudo(8),
      organizacionId: f.texto(9).isNotEmpty ? f.texto(9) : organizacionPorDefecto,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
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
