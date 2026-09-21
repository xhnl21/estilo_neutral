import 'number_parser.dart';

/// Modelo de entidad CompraDivisa mapeado desde la hoja "compras_divisas"
/// Norma: ISO 8000 §4.1 / Trazabilidad cambiaria
class CompraDivisa {
  /// Columna A: ID de la operación (formato cd00000001)
  final String id;

  /// Columna B: Fecha de la compra ISO 8601 (YYYY-MM-DD)
  final DateTime fechaCompra;

  /// Columna C: Fecha de recepción/entrega de fondos ISO 8601 (YYYY-MM-DD)
  final DateTime fechaEntrega;

  /// Columna D: Monto de capital en USD adquirido
  final double capitalUsd;

  /// Columna E: Comisión cobrada por Binance/P2P en USD
  final double comisionBinanceUsd;

  /// Columna F: Número de orden externo en la plataforma
  final String numeroOrden;

  /// Columna G: Plataforma utilizada (Binance, Zinli, etc.)
  final String plataforma;

  /// Columna H: Contraparte / Vendedor P2P
  final String vendedor;

  /// Columna I: Tasa oficial BCV del día
  final double tasaBcv;

  /// Columna J: Tasa efectiva en USD
  final double tasaUsd;

  /// Columna K: Validación lógica de la transacción ('OK' | 'ERROR')
  final String validacion;

  /// Columna L: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const CompraDivisa({
    required this.id,
    required this.fechaCompra,
    required this.fechaEntrega,
    required this.capitalUsd,
    required this.comisionBinanceUsd,
    required this.numeroOrden,
    required this.plataforma,
    required this.vendedor,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.validacion,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  factory CompraDivisa.fromRow(List<dynamic> row) {
    return CompraDivisa(
      id: row.isNotEmpty ? row[0].toString() : '',
      fechaCompra: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      fechaEntrega: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
      capitalUsd: row.length > 3 ? parseSheetDouble(row[3]) : 0.0,
      comisionBinanceUsd: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      numeroOrden: row.length > 5 ? row[5].toString() : '',
      plataforma: row.length > 6 ? row[6].toString() : '',
      vendedor: row.length > 7 ? row[7].toString() : '',
      tasaBcv: row.length > 8 ? parseSheetDouble(row[8]) : 0.0,
      tasaUsd: row.length > 9 ? parseSheetDouble(row[9]) : 0.0,
      validacion: row.length > 10 ? row[10].toString() : 'OK',
      organizacionId: row.length > 11 && row[11].toString().trim().isNotEmpty
          ? row[11].toString().trim()
          : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  List<dynamic> toRow({int rowNumber = 2}) {
    return [
      id,
      fechaCompra.toIso8601String().split('T').first,
      fechaEntrega.toIso8601String().split('T').first,
      capitalUsd.toStringAsFixed(2),
      comisionBinanceUsd.toStringAsFixed(2),
      numeroOrden,
      plataforma,
      vendedor,
      tasaBcv.toStringAsFixed(2),
      tasaUsd.toStringAsFixed(2),
      '=IF(B$rowNumber="","",IF(AND(C$rowNumber>=B$rowNumber, E$rowNumber>=0, D$rowNumber>0), "OK", "ERROR"))',
      organizacionId,
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha_compra': fechaCompra.toIso8601String().split('T').first,
      'fecha_entrega': fechaEntrega.toIso8601String().split('T').first,
      'capital_usd': capitalUsd,
      'comision_binance_usd': comisionBinanceUsd,
      'numero_orden': numeroOrden,
      'plataforma': plataforma,
      'vendedor': vendedor,
      'tasa_bcv': tasaBcv,
      'tasa_usd': tasaUsd,
      'validacion': validacion,
      'organizacion_id': organizacionId,
    };
  }
}
