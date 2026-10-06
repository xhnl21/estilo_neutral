import 'fecha_hoja.dart';
import 'number_parser.dart';

/// Modelo de entidad ResumenDiario mapeado desde la hoja "resumen_diario"
/// Norma: ISO 8000 §5.3 / Automatización de métricas
class ResumenDiario {
  /// Columna A: ID único (formato rd00000001), generado por el servidor.
  /// Vacío mientras el cierre no se confirmó en Sheets.
  final String id;

  /// Columna B: Fecha del resumen ISO 8601 (YYYY-MM-DD). Junto con la
  /// organización es única: un cierre por día y organización.
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

  /// Columna I: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const ResumenDiario({
    this.id = '',
    required this.fecha,
    required this.nroVentas,
    required this.totalBs,
    required this.totalUsd,
    required this.tasaBcv,
    required this.tasaUsd,
    required this.usdComprados,
    required this.usdVendidos,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  /// Acepta el formato actual (con columna `id` en A) y el anterior (sin
  /// ella, fecha en A), por si la hoja todavía no se migró.
  ///
  /// Lanza [FormatException] si la fecha es ilegible (no se inventa "hoy").
  factory ResumenDiario.fromRow(List<dynamic> row) {
    final conId = row.isNotEmpty && parseFechaHoja(row[0].toString()) == null;
    final o = conId ? 1 : 0;
    String celda(int i) => row.length > i + o ? row[i + o].toString().trim() : '';
    return ResumenDiario(
      id: conId ? row[0].toString().trim() : '',
      fecha: fechaHojaObligatoria(celda(0), 'resumen_diario.fecha'),
      nroVentas: parseSheetInt(celda(1)),
      totalBs: parseSheetDouble(celda(2)),
      totalUsd: parseSheetDouble(celda(3)),
      tasaBcv: parseSheetDouble(celda(4)),
      tasaUsd: parseSheetDouble(celda(5)),
      usdComprados: parseSheetDouble(celda(6)),
      usdVendidos: parseSheetDouble(celda(7)),
      organizacionId: celda(8).isNotEmpty ? celda(8) : '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
    );
  }

  /// Fecha en formato yyyy-MM-dd (clave del cierre junto con la organización).
  String get fechaIso => fecha.toIso8601String().split('T').first;

  ResumenDiario copyWith({
    String? id,
    DateTime? fecha,
    int? nroVentas,
    double? totalBs,
    double? totalUsd,
    double? tasaBcv,
    double? tasaUsd,
    double? usdComprados,
    double? usdVendidos,
    String? organizacionId,
  }) {
    return ResumenDiario(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      nroVentas: nroVentas ?? this.nroVentas,
      totalBs: totalBs ?? this.totalBs,
      totalUsd: totalUsd ?? this.totalUsd,
      tasaBcv: tasaBcv ?? this.tasaBcv,
      tasaUsd: tasaUsd ?? this.tasaUsd,
      usdComprados: usdComprados ?? this.usdComprados,
      usdVendidos: usdVendidos ?? this.usdVendidos,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'fecha': fechaIso,
      'nro_ventas': nroVentas,
      'total_bs': totalBs,
      'total_usd': totalUsd,
      'tasa_bcv': tasaBcv,
      'tasa_usd': tasaUsd,
      'usd_comprados': usdComprados,
      'usd_vendidos': usdVendidos,
      'organizacion_id': organizacionId,
    };
  }
}
