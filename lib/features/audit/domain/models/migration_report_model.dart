/// Read Model: MigrationReport (reporte_migracion - SOLO LECTURA)
class MigrationReportModel {
  final String metrica;
  final String valorEstado;
  final String normaAplicada;
  final String observaciones;

  const MigrationReportModel({
    required this.metrica,
    required this.valorEstado,
    required this.normaAplicada,
    required this.observaciones,
  });

  factory MigrationReportModel.fromRow(List<dynamic> row) {
    return MigrationReportModel(
      metrica: row.isNotEmpty ? row[0].toString() : '',
      valorEstado: row.length > 1 ? row[1].toString() : '',
      normaAplicada: row.length > 2 ? row[2].toString() : '',
      observaciones: row.length > 3 ? row[3].toString() : '',
    );
  }
}
