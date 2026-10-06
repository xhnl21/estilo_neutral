/// Lectura de una fila de Google Sheets cuya columna A es `id` (ver
/// docs/estandar-hojas.md, R1). Tolera el formato anterior, sin columna
/// `id`, para hojas que todavía no se migraron: la columna A se reconoce como
/// ID solo si tiene el formato `<prefijo>00000001`.
class FilaHoja {
  final String id;
  final List<dynamic> _celdas;

  FilaHoja._(this.id, this._celdas);

  factory FilaHoja.leer(List<dynamic> row, String prefijo) {
    final primera = row.isNotEmpty ? row[0].toString().trim() : '';
    final conId = RegExp('^$prefijo\\d{8}\$').hasMatch(primera);
    return FilaHoja._(conId ? primera : '', conId ? row.sublist(1) : row);
  }

  /// Celda [i] (0 = primera columna después del `id`), recortada.
  String texto(int i) => i < _celdas.length ? _celdas[i].toString().trim() : '';

  /// Celda [i] sin recortar (para textos libres, como JSON).
  String crudo(int i) => i < _celdas.length ? _celdas[i].toString() : '';
}

const organizacionPorDefecto = '67774411-6aa1-4aa3-a4b2-d3fc6913b768';
