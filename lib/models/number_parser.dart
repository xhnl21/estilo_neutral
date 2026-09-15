/// Utilidad para el parseo resiliente de números de Google Sheets
/// Cumplimiento: ISO 8000 §4.2 (Calidad de datos y normalización de tipos)
library;

double parseSheetDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  final raw = value.toString().trim();
  if (raw.isEmpty) return defaultValue;

  // Si tiene puntos y comas (ej. 1.234,56 o 1,234.56)
  if (raw.contains('.') && raw.contains(',')) {
    if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
      // Formato latinoamericano/europeo: 1.234,56
      final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? defaultValue;
    } else {
      // Formato anglosajón: 1,234.56
      final normalized = raw.replaceAll(',', '');
      return double.tryParse(normalized) ?? defaultValue;
    }
  }

  // Si sólo tiene coma como separador decimal (ej. "20,00", "0,00")
  if (raw.contains(',')) {
    return double.tryParse(raw.replaceAll(',', '.')) ?? defaultValue;
  }

  return double.tryParse(raw) ?? defaultValue;
}

int parseSheetInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  final raw = value.toString().trim();
  if (raw.isEmpty) return defaultValue;
  final directInt = int.tryParse(raw);
  if (directInt != null) return directInt;
  return parseSheetDouble(value, defaultValue.toDouble()).round();
}
