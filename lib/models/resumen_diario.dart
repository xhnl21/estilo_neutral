import 'number_parser.dart';

/// Modelo de entidad ResumenDiario mapeado desde la hoja "resumen_diario"
/// Norma: ISO 8000 §5.3 / Automatización de métricas
class ResumenDiario {
  /// Columna A: Fecha del resumen ISO 8601 (YYYY-MM-DD)
  final DateTime fecha;

  /// Columna B: Cantidad de ventas realizadas en el día
  final int nroVentas;

  /// Columna C: Monto total recaudado en Bolívares
  final double totalBs;

  /// Columna D: Monto total consolidado en USD
  final double totalUsd;

  /// Columna E: Tasa oficial BCV ponderada del día
  final double tasaBcv;

  /// Columna F: Tasa paralela/Binance promedio del día
  final double tasaUsd;

  /// Columna G: Total de USD comprados en operaciones P2P
  final double usdComprados;

  /// Columna H: Total de USD vendidos a clientes
  final double usdVendidos;

  const ResumenDiario({
    required this.fecha,
    required this.nroVentas,
    required this.totalBs,
    required this.totalUsd,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.usdComprados,
    required this.usdVendidos,
  });

  factory ResumenDiario.fromRow(List<dynamic> row) {
    return ResumenDiario(
      fecha: row.isNotEmpty ? DateTime.tryParse(row[0].toString()) ?? DateTime.now() : DateTime.now(),
      nroVentas: row.length > 1 ? parseSheetInt(row[1]) : 0,
      totalBs: row.length > 2 ? parseSheetDouble(row[2]) : 0.0,
      totalUsd: row.length > 3 ? parseSheetDouble(row[3]) : 0.0,
      tasaBcv: row.length > 4 ? parseSheetDouble(row[4]) : 0.0,
      tasaUsd: row.length > 5 ? parseSheetDouble(row[5]) : 0.0,
      usdComprados: row.length > 6 ? parseSheetDouble(row[6]) : 0.0,
      usdVendidos: row.length > 7 ? parseSheetDouble(row[7]) : 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha.toIso8601String().split('T').first,
      'nro_ventas': nroVentas,
      'total_bs': totalBs,
      'total_usd': totalUsd,
      'tasa_bcv': tasaBcv,
      'tasa_usd': tasaUsd,
      'usd_comprados': usdComprados,
      'usd_vendidos': usdVendidos,
    };
  }
}
