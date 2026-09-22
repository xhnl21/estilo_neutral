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

  const Usuario({
    required this.id,
    required this.email,
    this.nombre = '',
  });

  factory Usuario.fromRow(List<dynamic> row) {
    return Usuario(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      email: row.length > 1 ? row[1].toString().trim().toLowerCase() : '',
      nombre: row.length > 2 ? row[2].toString().trim() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
    };
  }
}
