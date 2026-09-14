/// Read Model: AuditLogEntry (audit_log - SOLO LECTURA)
class AuditLogModel {
  final String timestampIso8601;
  final String usuario;
  final String hoja;
  final String celda;
  final String valorAnterior;
  final String valorNuevo;
  final String accion;
  final String normaAplicada;
  final String observaciones;

  const AuditLogModel({
    required this.timestampIso8601,
    required this.usuario,
    required this.hoja,
    required this.celda,
    required this.valorAnterior,
    required this.valorNuevo,
    required this.accion,
    required this.normaAplicada,
    required this.observaciones,
  });

  factory AuditLogModel.fromRow(List<dynamic> row) {
    return AuditLogModel(
      timestampIso8601: row.isNotEmpty ? row[0].toString() : '',
      usuario: row.length > 1 ? row[1].toString() : '',
      hoja: row.length > 2 ? row[2].toString() : '',
      celda: row.length > 3 ? row[3].toString() : '',
      valorAnterior: row.length > 4 ? row[4].toString() : '',
      valorNuevo: row.length > 5 ? row[5].toString() : '',
      accion: row.length > 6 ? row[6].toString() : '',
      normaAplicada: row.length > 7 ? row[7].toString() : '',
      observaciones: row.length > 8 ? row[8].toString() : '',
    );
  }
}
