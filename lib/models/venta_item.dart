import 'number_parser.dart';

/// Modelo de entidad Ítem de Venta mapeado desde la hoja "venta_items".
/// Detalle de una factura (hoja "ventas"): una fila por producto comprado
/// dentro de esa venta — relación 1:N venta→ítems, análoga a un renglón de
/// factura. El precio se captura al momento de la venta (no se recalcula si
/// el precio del producto cambia después en Inventario).
class VentaItem {
  /// Columna A: ID único del ítem (formato vi00000001)
  final String id;

  /// Columna B: Clave foránea a la venta/factura (ventas.id)
  final String ventaId;

  /// Columna C: Clave foránea al producto (inventario.id)
  final String itemId;

  /// Columna D: Cantidad comprada de este producto (>= 1)
  final int cantidad;

  /// Columna E: Precio unitario en USD capturado al momento de la venta
  final double precioUsd;

  /// Columna F: Subtotal en USD (cantidad * precioUsd, calculado mediante fórmula)
  final double subtotalUsd;

  const VentaItem({
    required this.id,
    required this.ventaId,
    required this.itemId,
    required this.cantidad,
    required this.precioUsd,
    required this.subtotalUsd,
  });

  factory VentaItem.fromRow(List<dynamic> row) {
    return VentaItem(
      id: row.isNotEmpty ? row[0].toString() : '',
      ventaId: row.length > 1 ? row[1].toString() : '',
      itemId: row.length > 2 ? row[2].toString() : '',
      cantidad: row.length > 3 ? parseSheetInt(row[3], 1) : 1,
      precioUsd: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      subtotalUsd: row.length > 5 ? parseSheetDouble(row[5]) : 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'item_id': itemId,
      'cantidad': cantidad,
      'precio_usd': precioUsd,
      'subtotal_usd': subtotalUsd,
    };
  }
}
