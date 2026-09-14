/// Read Model: ChecklistIsoItem (checklist_iso - SOLO LECTURA)
class ChecklistIsoModel {
  final int nro;
  final String control;
  final String norma;
  final String estado;
  final String evidencia;
  final String timestamp;

  const ChecklistIsoModel({
    required this.nro,
    required this.control,
    required this.norma,
    required this.estado,
    required this.evidencia,
    required this.timestamp,
  });

  factory ChecklistIsoModel.fromRow(List<dynamic> row) {
    return ChecklistIsoModel(
      nro: row.isNotEmpty ? int.tryParse(row[0].toString()) ?? 0 : 0,
      control: row.length > 1 ? row[1].toString() : '',
      norma: row.length > 2 ? row[2].toString() : '',
      estado: row.length > 3 ? row[3].toString() : '☐',
      evidencia: row.length > 4 ? row[4].toString() : '',
      timestamp: row.length > 5 ? row[5].toString() : '',
    );
  }
}
