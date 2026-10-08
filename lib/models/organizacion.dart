/// Modelo de entidad Organización mapeado desde la hoja "organizaciones".
/// Fuente de verdad para las organizaciones que usan el sistema (multi-organización).
/// Mantenida manualmente por el dueño del negocio en Google Sheets.
///
/// La moneda base y la tasa manual de la organización YA NO viven acá: son
/// filas en "moneda_organizacion" y "tasas" respectivamente — evita
/// duplicar la misma fuente de verdad en dos lugares (ver
/// [SheetsDataService.monedaOrganizacion] y
/// [SheetsDataService.tasaManualOrganizacion]).
class Organizacion {
  /// Columna A: Identificador único de la organización (UUID)
  final String id;

  /// Columna B: Nombre visible de la organización
  final String nombre;

  /// Columna C: correo de la organización. Es el "Responder a" de los
  /// correos que la organización envía a sus clientes; vacío = no envía.
  final String email;

  const Organizacion({
    required this.id,
    this.nombre = '',
    this.email = '',
  });

  /// Mismo formato que validan el resto de los formularios y el Apps Script.
  static final formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get tieneEmail => formatoEmail.hasMatch(email);

  factory Organizacion.fromRow(List<dynamic> row) {
    return Organizacion(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      nombre: row.length > 1 ? row[1].toString().trim() : '',
      email: row.length > 2 ? row[2].toString().trim().toLowerCase() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
    };
  }
}
