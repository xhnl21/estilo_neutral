import 'number_parser.dart';

/// Modelo de entidad Abono mapeado desde la hoja "abonos".
/// Historial de pagos parciales de una factura (hoja "ventas") — una fila
/// por cada abono registrado, con su propio método de pago. Relación 1:N
/// venta→abonos, análoga a [VentaItem] para los productos de la factura.
class Abono {
  /// Columna A: ID único del abono (formato ab00000001)
  final String id;

  /// Columna B: Clave foránea a la venta/factura (ventas.id)
  final String ventaId;

  /// Columna C: Fecha Y HORA en que se registró el abono (ISO 8601 completo,
  /// no solo la fecha) — a diferencia de otras fechas del sistema, aquí
  /// importa el momento exacto del pago, no solo el día.
  final DateTime fecha;

  /// Columna D: Monto abonado en USD
  final double monto;

  /// Columna E: Clave foránea al método de pago usado en este abono
  /// (metodo pago.id) — no el nombre, para mantener la relación íntegra
  /// aunque el método se renombre más adelante.
  final String metodoPagoId;

  /// Columna F: Clave foránea a la tasa aplicada (tasas.id) — no el valor
  /// ni el origen ('bcv'/'manual') duplicados aquí: ambos se resuelven
  /// haciendo el JOIN lógico contra `tasas` (ver
  /// [SheetsDataService.tasaPorId]). Se captura sola, no la escribe el
  /// usuario — el usuario solo elige qué origen usar.
  final String tasaId;

  const Abono({
    required this.id,
    required this.ventaId,
    required this.fecha,
    required this.monto,
    required this.metodoPagoId,
    required this.tasaId,
  });

  factory Abono.fromRow(List<dynamic> row) {
    return Abono(
      id: row.isNotEmpty ? row[0].toString() : '',
      ventaId: row.length > 1 ? row[1].toString() : '',
      fecha: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
      monto: row.length > 3 ? parseSheetDouble(row[3]) : 0.0,
      metodoPagoId: row.length > 4 ? row[4].toString() : '',
      tasaId: row.length > 5 ? row[5].toString() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'fecha': fecha.toIso8601String(),
      'monto': monto,
      'metodo_pago': metodoPagoId,
      'tasa_id': tasaId,
    };
  }
}
