import 'dart:math' as math;

/// Implementación nativa y optimizada del algoritmo de Distancia de Levenshtein en Dart.
///
/// Calcula la cantidad mínima de operaciones (inserciones, eliminaciones, sustituciones)
/// requeridas para transformar una cadena [s] en otra [t].
///
/// Optimización de espacio: utiliza solo dos vectores de tamaño `min(m, n) + 1` en lugar
/// de una matriz completa de `(m+1) x (n+1)`.
abstract final class Levenshtein {
  /// Calcula la distancia de edición entre [s] y [t].
  ///
  /// Si alguna cadena es vacía, la distancia es la longitud de la otra cadena.
  /// Si ambas son idénticas, retorna 0.
  static int distance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    // Asegurar que 'b' sea la cadena más corta para minimizar uso de memoria
    final a = s.length >= t.length ? s : t;
    final b = s.length >= t.length ? t : s;

    final m = a.length;
    final n = b.length;

    var v0 = List<int>.generate(n + 1, (i) => i);
    var v1 = List<int>.filled(n + 1, 0);

    for (var i = 0; i < m; i++) {
      v1[0] = i + 1;
      final aChar = a.codeUnitAt(i);

      for (var j = 0; j < n; j++) {
        final bChar = b.codeUnitAt(j);
        final cost = (aChar == bChar) ? 0 : 1;

        v1[j + 1] = math.min(
          v1[j] + 1, // Inserción
          math.min(
            v0[j + 1] + 1, // Eliminación
            v0[j] + cost, // Sustitución
          ),
        );
      }

      // Intercambiar buffers para la siguiente fila
      final temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[n];
  }

  /// Calcula la similitud normalizada entre 0.0 y 1.0 (1.0 = idénticos, 0.0 = totalmente disímiles).
  static double similarity(String s, String t) {
    if (s == t) return 1.0;
    final maxLen = math.max(s.length, t.length);
    if (maxLen == 0) return 1.0;
    final dist = distance(s, t);
    return (maxLen - dist) / maxLen;
  }
}
