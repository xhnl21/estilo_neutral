/// Lee una fecha tal como la devuelve gviz (CSV de Google Sheets).
///
/// Acepta ISO 8601 (`2026-10-06`, `2026-10-06T10:30:00`), el formato con
/// espacio (`2026-10-06 10:30:00`), el local dd/MM/yyyy (`6/10/2026`, con o
/// sin hora) y el literal `Date(2026,9,6)` de gviz (mes base 0).
///
/// Devuelve `null` si no la reconoce. Nunca inventa una fecha: un valor
/// ilegible no se convierte en "hoy" (regla R7 de docs/estandar-hojas.md).
DateTime? parseFechaHoja(String? valor) {
  final texto = valor?.trim().replaceFirst(RegExp("^'"), '') ?? '';
  if (texto.isEmpty) return null;

  final iso = DateTime.tryParse(texto);
  if (iso != null) return iso;

  final gviz = RegExp(r'^Date\((\d{4}),(\d{1,2}),(\d{1,2})(?:,(\d{1,2}),(\d{1,2}),(\d{1,2}))?\)$').firstMatch(texto);
  if (gviz != null) {
    int g(int i) => int.tryParse(gviz.group(i) ?? '') ?? 0;
    return DateTime(g(1), g(2) + 1, g(3), g(4), g(5), g(6));
  }

  final local = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$').firstMatch(texto);
  if (local != null) {
    int g(int i) => int.tryParse(local.group(i) ?? '') ?? 0;
    final dia = g(1), mes = g(2), anio = g(3);
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    final fecha = DateTime(anio, mes, dia, g(4), g(5), g(6));
    // Descarta fechas que se desbordan (31/02 → 03/03).
    return fecha.month == mes ? fecha : null;
  }
  return null;
}

/// Como [parseFechaHoja], pero lanza [FormatException] si la fecha es
/// ilegible: para columnas obligatorias, donde el que lee descarta la fila
/// (y lo registra) en vez de inventar una fecha.
DateTime fechaHojaObligatoria(String? valor, String columna) {
  final fecha = parseFechaHoja(valor);
  if (fecha == null) throw FormatException('Fecha ilegible en $columna', valor);
  return fecha;
}
