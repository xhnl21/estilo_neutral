/// Modelo de entidad ChecklistISO mapeado desde la hoja "checklist_iso"
/// Entidad de SOLO LECTURA (Verificación formal de 20 controles de auditoría)
class ChecklistISO {
  /// Columna A: Número secuencial del control (1..20)
  final int nro;

  /// Columna B: Descripción del control de auditoría
  final String control;

  /// Columna C: Norma de referencia (ISO 27001, ISO 8000, ISO 8601, etc.)
  final String norma;

  /// Columna D: Estado de cumplimiento ('☑' / '☐' / 'N/A')
  final String estado;

  /// Columna E: Evidencia comprobable o referencia de celda
  final String evidencia;

  /// Columna F: Timestamp ISO 8601 de verificación
  final DateTime timestamp;

  const ChecklistISO({
    required this.nro,
    required this.control,
    required this.norma,
    required this.estado,
    required this.evidencia,
    required this.timestamp,
  });

  factory ChecklistISO.fromRow(List<dynamic> row) {
    return ChecklistISO(
      nro: row.isNotEmpty ? int.tryParse(row[0].toString()) ?? 0 : 0,
      control: row.length > 1 ? row[1].toString() : '',
      norma: row.length > 2 ? row[2].toString() : '',
      estado: row.length > 3 ? row[3].toString() : '☐',
      evidencia: row.length > 4 ? row[4].toString() : '',
      timestamp: row.length > 5 ? DateTime.tryParse(row[5].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nro': nro,
      'control': control,
      'norma': norma,
      'estado': estado,
      'evidencia': evidencia,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
