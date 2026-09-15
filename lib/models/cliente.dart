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

  const Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.saldoDeudaUsd,
    required this.fechaRegistro,
  });

  factory Cliente.fromRow(List<dynamic> row) {
    return Cliente(
      id: row.isNotEmpty ? row[0].toString() : '',
      nombre: row.length > 1 ? row[1].toString() : '',
      telefono: row.length > 2 ? row[2].toString() : '',
      email: row.length > 3 ? row[3].toString() : '',
      saldoDeudaUsd: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      fechaRegistro: row.length > 5 ? DateTime.tryParse(row[5].toString()) ?? DateTime.now() : DateTime.now(),
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
    };
  }
}
