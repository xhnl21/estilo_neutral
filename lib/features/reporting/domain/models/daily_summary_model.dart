/// Read Model: DailySummary (resumen_diario - SOLO LECTURA)
class DailySummaryModel {
  final String fecha;
  final int nroVentas;
  final double totalBs;
  final double totalUsd;
  final double tasaBcv;
  final double tasaUsd;
  final double usdComprados;
  final double usdVendidos;

  const DailySummaryModel({
    required this.fecha,
    required this.nroVentas,
    required this.totalBs,
    required this.totalUsd,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.usdComprados,
    required this.usdVendidos,
  });

  factory DailySummaryModel.fromRow(List<dynamic> row) {
    return DailySummaryModel(
      fecha: row.isNotEmpty ? row[0].toString() : '',
      nroVentas: row.length > 1 ? int.tryParse(row[1].toString()) ?? 0 : 0,
      totalBs: row.length > 2 ? double.tryParse(row[2].toString()) ?? 0.0 : 0.0,
      totalUsd: row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0,
      tasaBcv: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      tasaUsd: row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0,
      usdComprados: row.length > 6 ? double.tryParse(row[6].toString()) ?? 0.0 : 0.0,
      usdVendidos: row.length > 7 ? double.tryParse(row[7].toString()) ?? 0.0 : 0.0,
    );
  }
}
