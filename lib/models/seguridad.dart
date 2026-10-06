import 'fila_hoja.dart';

/// Modelo de entidad Seguridad mapeado desde la hoja "seguridad".
/// Configuración de mecanismos de autenticación disponibles, con **una fila
/// por usuario** (no por organización): así, si el equipo de un usuario no
/// puede cumplir el método elegido, la corrección automática (ver
/// `SeguridadPage`) solo afecta a ese usuario, no a toda la organización.
/// Los tres métodos (`biometrico`, `desbloqueoFacial`, `dosFactores`) son
/// **mutuamente excluyentes**: a lo sumo uno puede estar activo por usuario.
/// Usar [metodoActivo] para leer cuál está activo, y
/// `SheetsDataService.setMetodoSeguridad` para cambiarlo.
class Seguridad {
  /// Columna A: Autenticación biométrica (huella dactilar) habilitada
  /// ID generado por el servidor (sg00000001). Vacío si aún no se confirmó.
  final String id;

  final bool biometrico;

  /// Columna B: Desbloqueo facial habilitado
  final bool desbloqueoFacial;

  /// Columna C: Verificación en dos pasos (2FA) habilitada
  final bool dosFactores;

  /// Columna D: Correo del usuario al que pertenece este registro
  final String usuarioEmail;

  const Seguridad({
    this.id = '',
    this.biometrico = false,
    this.desbloqueoFacial = false,
    this.dosFactores = false,
    this.usuarioEmail = '',
  });

  factory Seguridad.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'sg');
    return Seguridad(
      id: f.id,
      biometrico: _parseBool(f.texto(0)),
      desbloqueoFacial: _parseBool(f.texto(1)),
      dosFactores: _parseBool(f.texto(2)),
      usuarioEmail: f.texto(3).toLowerCase(),
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

  /// Identificador del único método activo ('biometrico', 'desbloqueo_facial',
  /// 'dos_factores'), o `null` si no hay ninguno activo. Los tres campos son
  /// mutuamente excluyentes: a lo sumo uno puede estar en `true`.
  String? get metodoActivo {
    if (biometrico) return 'biometrico';
    if (desbloqueoFacial) return 'desbloqueo_facial';
    if (dosFactores) return 'dos_factores';
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'biometrico': biometrico,
      'desbloqueo_facial': desbloqueoFacial,
      'dos_factores': dosFactores,
      'usuario_email': usuarioEmail,
    };
  }
}
