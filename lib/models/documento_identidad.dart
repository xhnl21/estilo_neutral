/// Reglas de los documentos de identidad venezolanos usados en "clientes".
///
/// - V / E: cédula, solo dígitos.
/// - J / G: RIF, 8 dígitos + dígito verificador (módulo 11, algoritmo SENIAT).
/// - Cualquier otro tipo del catálogo (p. ej. pasaporte): alfanumérico.
///
/// El número se guarda normalizado (sin puntos, espacios ni guiones).
class DocumentoIdentidad {
  DocumentoIdentidad._();

  static const _tiposCedula = {'V', 'E'};
  static const _tiposRif = {'J', 'G'};

  /// Valor del prefijo en el cálculo del dígito verificador del RIF.
  static const _valorPrefijo = {'V': 1, 'E': 2, 'J': 3, 'P': 4, 'G': 5};
  static const _pesos = [3, 2, 7, 6, 5, 4, 3, 2];

  static bool esRif(String tipo) => _tiposRif.contains(tipo.toUpperCase());

  /// Tipos cuyo número es solo numérico (cédula y RIF).
  static bool esNumerico(String tipo) {
    final t = tipo.toUpperCase();
    return _tiposCedula.contains(t) || _tiposRif.contains(t);
  }

  /// Quita puntos, espacios y guiones (`J-12.345.678-9` → `123456789`).
  static String normalizar(String raw) =>
      raw.replaceAll(RegExp(r'[.\s-]'), '').toUpperCase();

  /// Dígito verificador de un RIF a partir del tipo y sus 8 dígitos base.
  static int? digitoVerificadorRif(String tipo, String ochoDigitos) {
    final prefijo = _valorPrefijo[tipo.toUpperCase()];
    if (prefijo == null || !RegExp(r'^\d{8}$').hasMatch(ochoDigitos)) {
      return null;
    }
    var suma = prefijo * 4;
    for (var i = 0; i < 8; i++) {
      suma += int.parse(ochoDigitos[i]) * _pesos[i];
    }
    final digito = 11 - (suma % 11);
    return digito >= 10 ? 0 : digito;
  }

  /// Devuelve el mensaje de error, o `null` si [numero] (ya normalizado) es
  /// válido para [tipo].
  static String? validar(String tipo, String numero) {
    if (esRif(tipo)) {
      if (!RegExp(r'^\d{9}$').hasMatch(numero)) {
        return 'RIF: 8 dígitos + dígito verificador (ej: 12345678-9)';
      }
      final esperado = digitoVerificadorRif(tipo, numero.substring(0, 8));
      if (esperado != int.parse(numero[8])) {
        return 'Dígito verificador del RIF inválido';
      }
      return null;
    }
    if (esNumerico(tipo)) {
      return RegExp(r'^\d{5,10}$').hasMatch(numero)
          ? null
          : 'Solo números, entre 5 y 10 dígitos';
    }
    return RegExp(r'^[A-Z0-9]{5,15}$').hasMatch(numero)
        ? null
        : 'Solo letras y números, entre 5 y 15 caracteres';
  }

  /// Formato de presentación: `V-12345678`, `J-12345678-9`.
  static String formatear(String tipo, String numero) {
    final t = tipo.toUpperCase();
    final n = normalizar(numero);
    if (esRif(t) && n.length == 9) {
      return '$t-${n.substring(0, 8)}-${n.substring(8)}';
    }
    return '$t-$n';
  }
}
