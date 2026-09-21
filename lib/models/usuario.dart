/// Modelo de entidad Usuario mapeado desde la hoja "usuarios".
/// Fuente de verdad para la asociación email -> organización (multi-organización).
/// Mantenida manualmente por el dueño del negocio en Google Sheets.
class Usuario {
  /// Columna A: Correo electrónico del usuario (normalizado a minúsculas)
  final String email;

  /// Columna B: Identificador de la organización a la que pertenece el usuario
  final String organizacionId;

  /// Columna C: Nombre del usuario (opcional)
  final String nombre;

  const Usuario({
    required this.email,
    required this.organizacionId,
    this.nombre = '',
  });

  factory Usuario.fromRow(List<dynamic> row) {
    return Usuario(
      email: row.isNotEmpty ? row[0].toString().trim().toLowerCase() : '',
      organizacionId: row.length > 1 ? row[1].toString().trim() : '',
      nombre: row.length > 2 ? row[2].toString().trim() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'organizacion_id': organizacionId,
      'nombre': nombre,
    };
  }
}
