/// Modelo de relación mapeado desde la hoja "usuario_organizacion".
/// Representa la membresía explícita de un usuario a una organización
/// (relación 1:N — una organización tiene muchos usuarios, cada usuario
/// pertenece a una única organización). Se modela como hoja de relación
/// separada, en vez de embeber `organizacion_id` directamente en "usuarios",
/// para mantener separadas las entidades (Usuario, Organización) de su
/// relación.
class UsuarioOrganizacion {
  /// Columna A: Correo del usuario (normalizado a minúsculas)
  final String usuarioEmail;

  /// Columna B: Identificador de la organización a la que pertenece
  final String organizacionId;

  const UsuarioOrganizacion({
    required this.usuarioEmail,
    required this.organizacionId,
  });

  factory UsuarioOrganizacion.fromRow(List<dynamic> row) {
    return UsuarioOrganizacion(
      usuarioEmail: row.isNotEmpty ? row[0].toString().trim().toLowerCase() : '',
      organizacionId: row.length > 1 ? row[1].toString().trim() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario_email': usuarioEmail,
      'organizacion_id': organizacionId,
    };
  }
}
