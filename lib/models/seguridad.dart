/// Modelo de entidad Seguridad mapeado desde la hoja "seguridad".
/// Configuración de mecanismos de autenticación disponibles, ahora con una fila
/// por organización (multi-organización) en lugar de un único registro global.
class Seguridad {
  /// Columna A: Autenticación biométrica (huella dactilar) habilitada
  final bool biometrico;

  /// Columna B: Desbloqueo facial habilitado
  final bool desbloqueoFacial;

  /// Columna C: Verificación en dos pasos (2FA) habilitada
  final bool dosFactores;

  /// Columna D: Identificador de la organización a la que pertenece este registro
  final String organizacionId;

  const Seguridad({
    this.biometrico = true,
    this.desbloqueoFacial = true,
    this.dosFactores = true,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory Seguridad.fromRow(List<dynamic> row) {
    return Seguridad(
      biometrico: _parseBool(row.isNotEmpty ? row[0] : null),
      desbloqueoFacial: _parseBool(row.length > 1 ? row[1] : null),
      dosFactores: _parseBool(row.length > 2 ? row[2] : null),
      organizacionId: row.length > 3 && row[3].toString().trim().isNotEmpty
          ? row[3].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    final normalized = value.toString().trim().toUpperCase();
    return normalized == 'TRUE' ||
        normalized == '1' ||
        normalized == 'SI' ||
        normalized == 'SÍ' ||
        normalized == '☑';
  }

  Seguridad copyWith({
    bool? biometrico,
    bool? desbloqueoFacial,
    bool? dosFactores,
    String? organizacionId,
  }) {
    return Seguridad(
      biometrico: biometrico ?? this.biometrico,
      desbloqueoFacial: desbloqueoFacial ?? this.desbloqueoFacial,
      dosFactores: dosFactores ?? this.dosFactores,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'biometrico': biometrico,
      'desbloqueo_facial': desbloqueoFacial,
      'dos_factores': dosFactores,
      'organizacion_id': organizacionId,
    };
  }
}
