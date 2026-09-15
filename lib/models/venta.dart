import 'enums.dart';
import 'number_parser.dart';

/// Modelo de entidad Venta mapeado desde la hoja transaccional "ventas"
/// Norma: ISO 8000 §5.3 / 3FN
class Venta {
  /// Columna A: ID de venta (formato v00000001)
  final String id;

  /// Columna B: Fecha de la venta ISO 8601 (YYYY-MM-DD)
  final DateTime fecha;

  /// Columna C: Clave foránea al cliente (clientes.id)
  final String clienteId;

  /// Columna D: Clave foránea al producto (inventario.id)
  final String itemId;

  /// Columna E: Cantidad vendida (>= 1)
  final int cantidad;

  /// Columna F: Tasa oficial BCV para la transacción
  final double tasaBcv;

  /// Columna G: Tasa paralela/Binance en USD
  final double tasaUsd;

  /// Columna H: Método de pago utilizado (enum TipoPago)
  final TipoPago tipoPago;

  /// Columna I: Comisión bancaria de pago móvil en Bs
  final double comisionPagoMovilBs;

  /// Columna J: Monto total en Bs (calculado mediante fórmula INDEX/MATCH)
  final double montoBs;

  /// Columna K: Monto total en USD (calculado mediante fórmula INDEX/MATCH)
  final double montoUsd;

  /// Columna L: Abono inicial o total efectuado en USD
  final double abonoUsd;

  /// Columna M: Deuda pendiente en USD (calculado N - L)
  final double deudaUsd;

  /// Columna N: Total a pagar en USD (calculado K)
  final double totalPagarUsd;

  /// Columna O: Estado de consistencia matemática ('OK' | 'ERROR')
  final String validacion;

  /// Columna P: Estado del ciclo de vida transaccional
  final EstadoVenta estado;

  const Venta({
    required this.id,
    required this.fecha,
    required this.clienteId,
    required this.itemId,
    required this.cantidad,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.tipoPago,
    required this.comisionPagoMovilBs,
    required this.montoBs,
    required this.montoUsd,
    required this.abonoUsd,
    required this.deudaUsd,
    required this.totalPagarUsd,
    required this.validacion,
    required this.estado,
  });

  factory Venta.fromRow(List<dynamic> row) {
    return Venta(
      id: row.isNotEmpty ? row[0].toString() : '',
      fecha: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      clienteId: row.length > 2 ? row[2].toString() : '',
      itemId: row.length > 3 ? row[3].toString() : '',
      cantidad: row.length > 4 ? parseSheetInt(row[4], 1) : 1,
      tasaBcv: row.length > 5 ? parseSheetDouble(row[5]) : 0.0,
      tasaUsd: row.length > 6 ? parseSheetDouble(row[6]) : 0.0,
      tipoPago: row.length > 7 ? TipoPago.fromString(row[7].toString()) : TipoPago.otro,
      comisionPagoMovilBs: row.length > 8 ? parseSheetDouble(row[8]) : 0.0,
      montoBs: row.length > 9 ? parseSheetDouble(row[9]) : 0.0,
      montoUsd: row.length > 10 ? parseSheetDouble(row[10]) : 0.0,
      abonoUsd: row.length > 11 ? parseSheetDouble(row[11]) : 0.0,
      deudaUsd: row.length > 12 ? parseSheetDouble(row[12]) : 0.0,
      totalPagarUsd: row.length > 13 ? parseSheetDouble(row[13]) : 0.0,
      validacion: row.length > 14 ? row[14].toString() : 'OK',
      estado: row.length > 15 ? EstadoVenta.fromString(row[15].toString()) : EstadoVenta.pendiente,
    );
  }

  List<dynamic> toRow({int rowNumber = 2}) {
    return [
      id,
      fecha.toIso8601String().split('T').first,
      clienteId,
      itemId,
      cantidad,
      tasaBcv.toStringAsFixed(2),
      tasaUsd.toStringAsFixed(2),
      tipoPago.label,
      comisionPagoMovilBs.toStringAsFixed(2),
      '=IFERROR(E$rowNumber*INDEX(inventario!G:G, MATCH(D$rowNumber, inventario!A:A, 0))*F$rowNumber, "ERROR")',
      '=IFERROR(E$rowNumber*INDEX(inventario!G:G, MATCH(D$rowNumber, inventario!A:A, 0)), "ERROR")',
      abonoUsd.toStringAsFixed(2),
      '=N$rowNumber-L$rowNumber',
      '=K$rowNumber',
      '=IF(AND(ABS(J$rowNumber-E$rowNumber*INDEX(inventario!G:G,MATCH(D$rowNumber,inventario!A:A,0))*F$rowNumber)<0.01, ABS(K$rowNumber-E$rowNumber*INDEX(inventario!G:G,MATCH(D$rowNumber,inventario!A:A,0)))<0.01, ABS(M$rowNumber-(N$rowNumber-L$rowNumber))<0.01),"OK","ERROR")',
      estado.label,
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String().split('T').first,
      'cliente_id': clienteId,
      'item_id': itemId,
      'cantidad': cantidad,
      'tasa_bcv': tasaBcv,
      'tasa_usd': tasaUsd,
      'tipo_pago': tipoPago.label,
      'comision_pago_movil_bs': comisionPagoMovilBs,
      'monto_bs': montoBs,
      'monto_usd': montoUsd,
      'abono_usd': abonoUsd,
      'deuda_usd': deudaUsd,
      'total_pagar_usd': totalPagarUsd,
      'validacion': validacion,
      'estado': estado.label,
    };
  }
}
