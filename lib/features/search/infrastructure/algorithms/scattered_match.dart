/// Algoritmo para validar coincidencias esparcidas (Scattered Matches).
///
/// Comprueba si todos los caracteres de un patrón [pattern] aparecen en el mismo
/// orden secuencial dentro de una cadena destino [target], admitiendo caracteres intermedios.
abstract final class ScatteredMatch {
  /// Retorna `true` si todos los caracteres de [pattern] existen en orden dentro de [target].
  ///
  /// Si [pattern] está vacío, retorna `true`.
  /// Si [pattern] es más largo que [target], retorna `false`.
  static bool isMatch(String pattern, String target) {
    if (pattern.isEmpty) return true;
    if (pattern.length > target.length) return false;

    var patternIdx = 0;
    final patternLen = pattern.length;
    final targetLen = target.length;

    for (var targetIdx = 0; targetIdx < targetLen; targetIdx++) {
      if (target.codeUnitAt(targetIdx) == pattern.codeUnitAt(patternIdx)) {
        patternIdx++;
        if (patternIdx == patternLen) {
          return true;
        }
      }
    }

    return false;
  }

  /// Encuentra los índices exactos en [target] que corresponden secuencialmente
  /// a cada carácter de [pattern].
  ///
  /// Retorna una lista con las posiciones encontradas, o `null` si no hay coincidencia completa.
  static List<int>? findMatchIndices(String pattern, String target) {
    if (pattern.isEmpty) return const [];
    if (pattern.length > target.length) return null;

    final indices = <int>[];
    var patternIdx = 0;
    final patternLen = pattern.length;
    final targetLen = target.length;

    for (var targetIdx = 0; targetIdx < targetLen; targetIdx++) {
      if (target.codeUnitAt(targetIdx) == pattern.codeUnitAt(patternIdx)) {
        indices.add(targetIdx);
        patternIdx++;
        if (patternIdx == patternLen) {
          return indices;
        }
      }
    }

    return null;
  }
}
