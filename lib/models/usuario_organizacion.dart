import 'fila_hoja.dart';

/// Membresía de un usuario a una organización (hoja "usuario_organizacion").
/// Columnas: id | usuario_email | organizacion_id
class UsuarioOrganizacion {
  /// ID generado por el servidor (uo00000001). Vacío si aún no se confirmó.
  final String id;
  final String usuarioEmail;
  final String organizacionId;

  const UsuarioOrganizacion({
    this.id = '',
    required this.usuarioEmail,
    required this.organizacionId,
  });

  factory UsuarioOrganizacion.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'uo');
    return UsuarioOrganizacion(
      id: f.id,
      usuarioEmail: f.texto(0).toLowerCase(),
      organizacionId: f.texto(1),
    );
  }

  UsuarioOrganizacion copyWith({String? id, String? usuarioEmail, String? organizacionId}) =>
      UsuarioOrganizacion(
        id: id ?? this.id,
        usuarioEmail: usuarioEmail ?? this.usuarioEmail,
        organizacionId: organizacionId ?? this.organizacionId,
      );

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'usuario_email': usuarioEmail,
      'organizacion_id': organizacionId,
    };
  }
}
