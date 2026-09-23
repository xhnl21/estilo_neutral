import 'number_parser.dart';

/// Registro atómico de tasa de cambio, mapeado desde la hoja "tasas".
/// Norma: 3FN — una fila = un hecho (una moneda, una fecha, un valor), en
/// vez de empaquetar USD/EUR/actual/anterior/% de cambio en una sola fila
/// (ese diseño anterior mezclaba varios hechos y datos derivados en una
/// misma fila). El % de cambio ya NO se almacena: se calcula comparando
/// contra el registro anterior de la misma moneda+fuente (ver
/// [SheetsDataService.cambioPctTasa]).
///
/// [fuente] distingue el origen: 'bcv' (automática, alimentada por el
/// módulo Tasas en Apps Script) o 'manual' (fijada por una organización).
/// [organizacionId] queda vacío para las tasas BCV globales, y con el id de
/// la organización dueña para las tasas manuales — así una tasa manual es
/// una fila más de esta misma tabla, con su propia clave primaria [id],
/// referenciable por FK desde `ventas`/`abonos` sin duplicar el valor.
class TasaRegistro {
  /// Columna A: ID único (formato t00000001)
  final String id;

  /// Columna B: Fecha del dato (BCV) o de la última actualización (manual)
  final DateTime fecha;

  /// Columna C: Moneda ('USD' | 'EUR')
  final String moneda;

  /// Columna D: Valor en Bs. por unidad de [moneda]
  final double valor;

  /// Columna E: Origen ('bcv' | 'manual')
  final String fuente;

  /// Columna F: FK a organizaciones.id — vacío si es una tasa BCV global
  final String organizacionId;

  const TasaRegistro({
    required this.id,
    required this.fecha,
    required this.moneda,
    required this.valor,
    required this.fuente,
    this.organizacionId = '',
  });

  factory TasaRegistro.fromRow(List<dynamic> row) {
    return TasaRegistro(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      fecha: row.length > 1 ? DateTime.tryParse(row[1].toString()) ?? DateTime.now() : DateTime.now(),
      moneda: row.length > 2 ? row[2].toString().trim().toUpperCase() : 'USD',
      valor: row.length > 3 ? parseSheetDouble(row[3]) : 0.0,
      fuente: row.length > 4 && row[4].toString().trim().isNotEmpty ? row[4].toString().trim().toLowerCase() : 'bcv',
      organizacionId: row.length > 5 ? row[5].toString().trim() : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String().split('T').first,
      'moneda': moneda,
      'valor': valor,
      'fuente': fuente,
      'organizacion_id': organizacionId,
    };
  }
}
