/// Modelo de entidad MonedaOrganizacion mapeado desde la hoja
/// "moneda_organizacion" — la moneda base seleccionada por cada
/// organización ('USD' o 'EUR'), separada en su propia hoja (en vez de una
/// columna suelta en "organizaciones") para no duplicar la misma fuente de
/// verdad en dos lugares distintos.
class MonedaOrganizacion {
  /// Columna A: ID único (formato mo00000001)
  final String id;

  /// Columna B: FK a organizaciones.id
  final String organizacionId;

  /// Columna C: Moneda seleccionada ('USD' | 'EUR')
  final String moneda;

  /// Columna D: Fecha y hora de la última actualización
  final DateTime actualizadoEn;

  const MonedaOrganizacion({
    required this.id,
    required this.organizacionId,
    required this.moneda,
    required this.actualizadoEn,
  });

  factory MonedaOrganizacion.fromRow(List<dynamic> row) {
    return MonedaOrganizacion(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      organizacionId: row.length > 1 ? row[1].toString().trim() : '',
      moneda: row.length > 2 && row[2].toString().trim().isNotEmpty
          ? row[2].toString().trim().toUpperCase()
          : 'USD',
      actualizadoEn: row.length > 3 ? DateTime.tryParse(row[3].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizacion_id': organizacionId,
      'moneda': moneda,
      'actualizado_en': actualizadoEn.toIso8601String(),
    };
  }
}
