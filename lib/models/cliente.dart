import 'documento_identidad.dart';
import 'number_parser.dart';

/// Modelo de entidad Cliente mapeado desde la hoja "clientes"
/// Norma: ISO 8000 §4.2 / GDPR Art. 5
class Cliente {
  /// Columna A: ID único (formato c00000001)
  final String id;

  /// Columna B: Nombre del cliente
  final String nombre;

  /// Columna C: Teléfono en formato internacional E.164 (+58...)
  final String telefono;

  /// Columna D: Correo electrónico validado
  final String email;

  /// Columna E: Saldo deudor en USD (calculado dinámicamente)
  final double saldoDeudaUsd;

  /// Columna F: Fecha de registro ISO 8601 (YYYY-MM-DD)
  final DateTime fechaRegistro;

  /// Columna G: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  /// Columna H: Tipo de documento (V, E, J, G)
  final String tipoDocumento;

  /// Columna I: Número de cédula o documento de identidad
  final String cedula;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.saldoDeudaUsd,
    required this.fechaRegistro,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    this.tipoDocumento = 'V',
    this.cedula = '',
  });

  /// Helper que devuelve el documento formateado (ej. "V-12345678",
  /// "J-12345678-9" o "" si no tiene)
  String get documentoCompleto => cedula.trim().isEmpty
      ? ''
      : DocumentoIdentidad.formatear(tipoDocumento, cedula);

  factory Cliente.fromRow(List<dynamic> row) {
    return Cliente(
      id: row.isNotEmpty ? row[0].toString() : '',
      nombre: row.length > 1 ? row[1].toString() : '',
      telefono: row.length > 2 ? row[2].toString() : '',
      email: row.length > 3 ? row[3].toString() : '',
      saldoDeudaUsd: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      fechaRegistro: row.length > 5 ? DateTime.tryParse(row[5].toString()) ?? DateTime.now() : DateTime.now(),
      organizacionId: row.length > 6 && row[6].toString().trim().isNotEmpty
          ? row[6].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
      tipoDocumento: row.length > 7 && row[7].toString().trim().isNotEmpty
          ? row[7].toString().trim().toUpperCase()
          : 'V',
      cedula: row.length > 8 ? row[8].toString().trim() : '',
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      nombre,
      telefono,
      email,
      saldoDeudaUsd.toStringAsFixed(2),
      fechaRegistro.toIso8601String().split('T').first,
      organizacionId,
      tipoDocumento,
      cedula,
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'saldo_deuda_usd': saldoDeudaUsd,
      'fecha_registro': fechaRegistro.toIso8601String().split('T').first,
      'organizacion_id': organizacionId,
      'tipo_documento': tipoDocumento,
      'cedula': cedula,
    };
  }

  Cliente copyWith({
    String? id,
    String? nombre,
    String? telefono,
    String? email,
    double? saldoDeudaUsd,
    DateTime? fechaRegistro,
    String? organizacionId,
    String? tipoDocumento,
    String? cedula,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      saldoDeudaUsd: saldoDeudaUsd ?? this.saldoDeudaUsd,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      organizacionId: organizacionId ?? this.organizacionId,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      cedula: cedula ?? this.cedula,
    );
  }
}
