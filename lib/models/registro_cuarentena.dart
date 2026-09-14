/// Modelo de entidad RegistroCuarentena mapeado desde la hoja "cuarentena"
/// Entidad de SOLO LECTURA (Preservación forense COBIT 2019 DSS05 / NIST SP 800-53)
class RegistroCuarentena {
  /// Columna A: ID original previo a la normalización
  final String idRegistroOriginal;

  /// Columna B: Hoja donde residía originalmente la fila
  final String hojaOrigen;

  /// Columna C: Fecha y hora de detección
  final DateTime fechaDeteccion;

  /// Columna D: Motivo de la puesta en cuarentena
  final String motivoCuarentena;

  /// Columna E: Payload JSON original íntegro
  final String datosOriginalesJson;

  /// Columna F: Estado de resolución (CONSOLIDADO, CORREGIDO)
  final String estado;

  /// Columna G: Explicación de la resolución
  final String resolucion;

  /// Columna H: Hash SHA-256 inmutable de la evidencia
  final String hashEvidencia;

  const RegistroCuarentena({
    required this.idRegistroOriginal,
    required this.hojaOrigen,
    required this.fechaDeteccion,
    required this.motivoCuarentena,
    required this.datosOriginalesJson,
    required this.estado,
    required this.resolucion,
    required this.hashEvidencia,
  });

  factory RegistroCuarentena.fromRow(List<dynamic> row) {
    return RegistroCuarentena(
      idRegistroOriginal: row.isNotEmpty ? row[0].toString() : '',
      hojaOrigen: row.length > 1 ? row[1].toString() : '',
      fechaDeteccion: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
      motivoCuarentena: row.length > 3 ? row[3].toString() : '',
      datosOriginalesJson: row.length > 4 ? row[4].toString() : '',
      estado: row.length > 5 ? row[5].toString() : '',
      resolucion: row.length > 6 ? row[6].toString() : '',
      hashEvidencia: row.length > 7 ? row[7].toString() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_registro_original': idRegistroOriginal,
      'hoja_origen': hojaOrigen,
      'fecha_deteccion': fechaDeteccion.toIso8601String(),
      'motivo_cuarentena': motivoCuarentena,
      'datos_originales_json': datosOriginalesJson,
      'estado': estado,
      'resolucion': resolucion,
      'hash_evidencia': hashEvidencia,
    };
  }
}
