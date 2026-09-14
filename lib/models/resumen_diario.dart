/// Modelo de entidad ResumenDiario mapeado desde la hoja "resumen_diario"
/// Entidad de SOLO LECTURA (Protegida bajo ISO/IEC 27001 §9.2)
class ResumenDiario {
  /// Columna A: Fecha consolidada
  final DateTime fecha;

  /// Columna B: Número total de ventas del día (=COUNTIF)
  final int nroVentas;

  /// Columna C: Monto total facturado en Bs (=SUMIF)
  final double totalBs;

  /// Columna D: Monto total facturado en USD (=SUMIF)
  final double totalUsd;

  /// Columna E: Tasa promedio BCV del día (=AVERAGEIF)
  final double tasaBcv;

  /// Columna F: Tasa promedio paralela/Binance del día (=AVERAGEIF)
  final double tasaUsd;

  /// Columna G: Total USD adquiridos mediante compras_divisas (=SUMIF)
  final double usdComprados;

  /// Columna H: Total USD cobrados/abonados de ventas (=SUMIF ventas!L:L)
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
      nroVentas: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
      totalBs: row.length > 2 ? double.tryParse(row[2].toString()) ?? 0.0 : 0.0,
      totalUsd: row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0,
      tasaBcv: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      tasaUsd: row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0,
      usdComprados: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0,
      usdVendidos: row.length > 7 ? double.tryParse(row[7].toString()) ?? 0.0 : 0.0,
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
