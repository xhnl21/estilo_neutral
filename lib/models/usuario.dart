import 'fila_hoja.dart';
/// Modelo de entidad Usuario mapeado desde la hoja "usuarios".
/// La organización a la que pertenece cada usuario ya no se embebe acá:
/// vive en la hoja de relación "usuario_organizacion" (ver [UsuarioOrganizacion]),
/// para mantener separada la entidad Usuario de su membresía a una organización.
/// Mantenida manualmente por el dueño del negocio en Google Sheets (o desde el
/// módulo "Usuarios" de la app).
class Usuario {
  /// Columna A: ID único (formato u00000001)
  final String id;

  /// Columna B: Correo electrónico del usuario (normalizado a minúsculas)
  final String email;

  /// Columna C: Nombre del usuario (opcional)
  final String nombre;

  /// Columna D: Tipo de documento (V, E, J, G)
  final String tipoDocumento;

  /// Columna E: Cédula o número de documento
  final String cedula;

  /// Columna F (`status`): un usuario inactivo no puede entrar ni escribir,
  /// pero su registro se conserva. Vacía = activo.
  final bool activo;

  const Usuario({
    required this.id,
    required this.email,
    this.nombre = '',
    this.tipoDocumento = 'V',
    this.cedula = '',
    this.activo = true,
  });

  /// Helper que devuelve el documento formateado (ej. "V-12345678" o "" si no tiene)
  String get documentoCompleto =>
      cedula.trim().isEmpty ? '' : '${tipoDocumento.toUpperCase()}-${cedula.trim()}';

  factory Usuario.fromRow(List<dynamic> row) {
    return Usuario(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      email: row.length > 1 ? row[1].toString().trim().toLowerCase() : '',
      nombre: row.length > 2 ? row[2].toString().trim() : '',
      tipoDocumento: row.length > 3 && row[3].toString().trim().isNotEmpty
          ? row[3].toString().trim().toUpperCase()
          : 'V',
      cedula: row.length > 4 ? row[4].toString().trim() : '',
      activo: estadoActivo(row.length > 5 ? row[5] : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'tipo_documento': tipoDocumento,
      'cedula': cedula,
      'status': activo,
    };
  }

  Usuario copyWith({
    String? id,
    String? email,
    String? nombre,
    String? tipoDocumento,
    String? cedula,
    bool? activo,
  }) {
    return Usuario(
      id: id ?? this.id,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      cedula: cedula ?? this.cedula,
      activo: activo ?? this.activo,
    );
  }
}
