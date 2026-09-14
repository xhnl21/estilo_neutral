/// Modelo de entidad CompraDivisa mapeado desde la hoja "compras_divisas"
/// Norma: ISO 8000 §4.2 / COBIT 2019
class CompraDivisa {
  /// Columna A: ID único (formato d00000001)
  final String id;

  /// Columna B: Fecha en que se emite la compra
  final DateTime fechaCompra;

  /// Columna C: Fecha en que se recibe la divisa
  final DateTime fechaEntrega;

  /// Columna D: Capital en USD adquirido
  final double capitalUsd;

  /// Columna E: Comisión cobrada en Binance u otra plataforma
  final double comisionBinanceUsd;

  /// Columna F: Número identificador de orden
  final String numeroOrden;

  /// Columna G: Plataforma (Binance, Banco, etc.)
  final String plataforma;

  /// Columna H: Vendedor o contraparte P2P
  final String vendedor;

  /// Columna I: Tasa oficial BCV de referencia
  final double tasaBcv;

  /// Columna J: Tasa efectiva en USD
  final double tasaUsd;

  /// Columna K: Validación lógica de la transacción ('OK' | 'ERROR')
  final String validacion;

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
  });

  factory CompraDivisa.fromRow(List<dynamic> row) {
    return CompraDivisa(
      id: row.isNotEmpty ? row[0].toString() : '',
      fechaCompra: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      fechaEntrega: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
      capitalUsd: row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0,
      comisionBinanceUsd: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      numeroOrden: row.length > 5 ? row[5].toString() : '',
      plataforma: row.length > 6 ? row[6].toString() : '',
      vendedor: row.length > 7 ? row[7].toString() : '',
      tasaBcv: row.length > 8 ? double.tryParse(row[8].toString()) ?? 0.0 : 0.0,
      tasaUsd: row.length > 9 ? double.tryParse(row[9].toString()) ?? 0.0 : 0.0,
      validacion: row.length > 10 ? row[10].toString() : 'OK',
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
    };
  }
}
