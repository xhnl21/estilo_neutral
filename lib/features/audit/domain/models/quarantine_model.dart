/// Read Model: QuarantineRecord (cuarentena - SOLO LECTURA)
class QuarantineModel {
  final String idRegistroOriginal;
  final String hojaOrigen;
  final String fechaDeteccion;
  final String motivoCuarentena;
  final String datosOriginalesJson;
  final String estado;
  final String resolucion;
  final String hashEvidencia;

  const QuarantineModel({
    required this.idRegistroOriginal,
    required this.hojaOrigen,
    required this.fechaDeteccion,
    required this.motivoCuarentena,
    required this.datosOriginalesJson,
    required this.estado,
    required this.resolucion,
    required this.hashEvidencia,
  });

  factory QuarantineModel.fromRow(List<dynamic> row) {
    return QuarantineModel(
      idRegistroOriginal: row.isNotEmpty ? row[0].toString() : '',
      hojaOrigen: row.length > 1 ? row[1].toString() : '',
      fechaDeteccion: row.length > 2 ? row[2].toString() : '',
      motivoCuarentena: row.length > 3 ? row[3].toString() : '',
      datosOriginalesJson: row.length > 4 ? row[4].toString() : '',
      estado: row.length > 5 ? row[5].toString() : '',
      resolucion: row.length > 6 ? row[6].toString() : '',
      hashEvidencia: row.length > 7 ? row[7].toString() : '',
    );
  }
}
