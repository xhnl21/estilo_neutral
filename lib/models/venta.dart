import 'enums.dart';
import 'number_parser.dart';

/// Modelo de entidad Venta (factura/header) mapeado desde la hoja "ventas".
/// Norma: ISO 8000 §5.3 / 3FN
///
/// Representa la cabecera de una factura: cliente, pago y totales. El
/// detalle de qué productos se compraron vive en la hoja de relación
/// "venta_items" (ver [VentaItem]) — una factura puede tener varios ítems
/// (relación 1:N venta→ítems), como una factura real con múltiples renglones.
class Venta {
  /// Columna A: ID de venta/factura (formato v00000001)
  final String id;

  /// Columna B: Fecha de la venta ISO 8601 (YYYY-MM-DD)
  final DateTime fecha;

  /// Columna C: Clave foránea al cliente (clientes.id)
  final String clienteId;

  /// Columna D: Tasa oficial BCV para la transacción
  final double tasaBcv;

  /// Columna E: Tasa paralela/Binance en USD
  final double tasaUsd;

  /// Columna F: Clave foránea al método de pago (metodo pago.id) utilizado
  /// en la venta original. El nombre a mostrar se resuelve contra la hoja
  /// "metodo pago" (ver [SheetsDataService.metodoPagoNombre]) — esta columna
  /// nunca guarda el nombre en texto, para no perder la relación si el
  /// método se renombra más adelante.
  final String metodoPagoId;

  /// Columna G: Comisión bancaria de pago móvil en Bs
  final double comisionPagoMovilBs;

  /// Columna H: Monto total en Bs (calculado como suma de los ítems)
  final double montoBs;

  /// Columna I: Monto total en USD (calculado como suma de los ítems)
  final double montoUsd;

  /// Columna J: Abono inicial o total efectuado en USD
  final double abonoUsd;

  /// Columna K: Deuda pendiente en USD (calculado L - J)
  final double deudaUsd;

  /// Columna L: Total a pagar en USD (calculado I)
  final double totalPagarUsd;

  /// Columna M: Estado de consistencia matemática ('OK' | 'ERROR')
  final String validacion;

  /// Columna N: Estado del ciclo de vida transaccional
  final EstadoVenta estado;

  /// Columna O: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const Venta({
    required this.id,
    required this.fecha,
    required this.clienteId,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.metodoPagoId,
    required this.comisionPagoMovilBs,
    required this.montoBs,
    required this.montoUsd,
    required this.abonoUsd,
    required this.deudaUsd,
    required this.totalPagarUsd,
    required this.validacion,
    required this.estado,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory Venta.fromRow(List<dynamic> row) {
    return Venta(
      id: row.isNotEmpty ? row[0].toString() : '',
      fecha: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      clienteId: row.length > 2 ? row[2].toString() : '',
      tasaBcv: row.length > 3 ? parseSheetDouble(row[3]) : 0.0,
      tasaUsd: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      metodoPagoId: row.length > 5 ? row[5].toString() : '',
      comisionPagoMovilBs: row.length > 6 ? parseSheetDouble(row[6]) : 0.0,
      montoBs: row.length > 7 ? parseSheetDouble(row[7]) : 0.0,
      montoUsd: row.length > 8 ? parseSheetDouble(row[8]) : 0.0,
      abonoUsd: row.length > 9 ? parseSheetDouble(row[9]) : 0.0,
      deudaUsd: row.length > 10 ? parseSheetDouble(row[10]) : 0.0,
      totalPagarUsd: row.length > 11 ? parseSheetDouble(row[11]) : 0.0,
      validacion: row.length > 12 ? row[12].toString() : 'OK',
      estado: row.length > 13 ? EstadoVenta.fromString(row[13].toString()) : EstadoVenta.pendiente,
      organizacionId: row.length > 14 && row[14].toString().trim().isNotEmpty
          ? row[14].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String().split('T').first,
      'cliente_id': clienteId,
      'tasa_bcv': tasaBcv,
      'tasa_usd': tasaUsd,
      'tipo_pago': metodoPagoId,
      'comision_pago_movil_bs': comisionPagoMovilBs,
      'monto_bs': montoBs,
      'monto_usd': montoUsd,
      'abono_usd': abonoUsd,
      'deuda_usd': deudaUsd,
      'total_pagar_usd': totalPagarUsd,
      'validacion': validacion,
      'estado': estado.label,
      'organizacion_id': organizacionId,
    };
  }
}
