/// Utilidad para la normalización eficiente de texto.
///
/// Convierte cadenas a minúsculas y elimina diacríticos/acentos para
/// permitir comparaciones insensibles a caracteres especiales y mayúsculas.
abstract final class TextNormalizer {
  static const Map<int, String> _diacriticsMap = {
    // a
    0x00E1: 'a', // á
    0x00E0: 'a', // à
    0x00E4: 'a', // ä
    0x00E2: 'a', // â
    0x00E3: 'a', // ã
    0x00C1: 'a', // Á
    0x00C0: 'a', // À
    0x00C4: 'a', // Ä
    0x00C2: 'a', // Â
    0x00C3: 'a', // Ã
    // e
    0x00E9: 'e', // é
    0x00E8: 'e', // è
    0x00EB: 'e', // ë
    0x00EA: 'e', // ê
    0x00C9: 'e', // É
    0x00C8: 'e', // È
    0x00CB: 'e', // Ë
    0x00CA: 'e', // Ê
    // i
    0x00ED: 'i', // í
    0x00EC: 'i', // ì
    0x00EF: 'i', // ï
    0x00EE: 'i', // î
    0x00CD: 'i', // Í
    0x00CC: 'i', // Ì
    0x00CF: 'i', // Ï
    0x00CE: 'i', // Î
    // o
    0x00F3: 'o', // ó
    0x00F2: 'o', // ò
    0x00F6: 'o', // ö
    0x00F4: 'o', // ô
    0x00F5: 'o', // õ
    0x00D3: 'o', // Ó
    0x00D2: 'o', // Ò
    0x00D6: 'o', // Ö
    0x00D4: 'o', // Ô
    0x00D5: 'o', // Õ
    // u
    0x00FA: 'u', // ú
    0x00F9: 'u', // ù
    0x00FC: 'u', // ü
    0x00FB: 'u', // û
    0x00DA: 'u', // Ú
    0x00D9: 'u', // Ù
    0x00DC: 'u', // Ü
    0x00DB: 'u', // Û
    // n / ñ
    0x00F1: 'n', // ñ
    0x00D1: 'n', // Ñ
    // c / ç
    0x00E7: 'c', // ç
    0x00C7: 'c', // Ç
  };

  /// Normaliza una cadena convirtiéndola a minúsculas y removiendo acentos/diacríticos.
  ///
  /// Si [text] es nulo o vacío, retorna una cadena vacía.
  static String normalize(String? text) {
    if (text == null || text.isEmpty) return '';

    final buffer = StringBuffer();
    final lower = text.toLowerCase();

    for (var i = 0; i < lower.length; i++) {
      final codeUnit = lower.codeUnitAt(i);
      final replacement = _diacriticsMap[codeUnit];
      if (replacement != null) {
        buffer.write(replacement);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }

    return buffer.toString();
  }

  /// Divide una cadena en palabras normalizadas, ignorando múltiples espacios consecutivos.
  static List<String> tokenize(String? text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }
}
