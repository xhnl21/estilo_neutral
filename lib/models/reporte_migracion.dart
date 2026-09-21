/// Modelo de entidad ReporteMigracion mapeado desde la hoja "reporte_migracion"
/// Entidad de SOLO LECTURA
class ReporteMigracion {
  /// Columna A: Control o Métrica auditada
  final String metrica;

  /// Columna B: Valor o Estado obtenido
  final String valorEstado;

  /// Columna C: Norma aplicada
  final String normaAplicada;

  /// Columna D: Observaciones técnicas
  final String observaciones;

  /// Columna E: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const ReporteMigracion({
    required this.metrica,
    required this.valorEstado,
    required this.normaAplicada,
    required this.observaciones,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory ReporteMigracion.fromRow(List<dynamic> row) {
    return ReporteMigracion(
      metrica: row.isNotEmpty ? row[0].toString() : '',
      valorEstado: row.length > 1 ? row[1].toString() : '',
      normaAplicada: row.length > 2 ? row[2].toString() : '',
      observaciones: row.length > 3 ? row[3].toString() : '',
      organizacionId: row.length > 4 && row[4].toString().trim().isNotEmpty
          ? row[4].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'metrica': metrica,
      'valor_estado': valorEstado,
      'norma_aplicada': normaAplicada,
      'observaciones': observaciones,
      'organizacion_id': organizacionId,
    };
  }
}
