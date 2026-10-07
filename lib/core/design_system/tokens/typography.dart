import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Escala tipográfica y reglas tipográficas para Estilo Neutral.
/// Basado en la fuente Inter (consistencia multiplataforma) y accesibilidad WCAG 2.2 AA.
abstract final class AppTypography {
  /// `true` solo en tests (test/flutter_test_config.dart): usa la fuente del
  /// sistema en vez de Inter. google_fonts carga Inter de forma asíncrona y,
  /// sin red ni la fuente en los assets, su error caía al azar dentro de
  /// cualquier test de widgets y lo hacía fallar.
  static bool usarFuenteDelSistema = false;

  static TextStyle _inter({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    Color? color,
    List<FontFeature>? fontFeatures,
  }) {
    if (usarFuenteDelSistema) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        fontFeatures: fontFeatures,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
      fontFeatures: fontFeatures,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ESCALA TIPOGRÁFICA (6 Niveles Normalizados)
  // ═══════════════════════════════════════════════════════════

  /// displayLarge (32px / w600 / h1.2) — Títulos principales de pantalla.
  static TextStyle get displayLarge => _inter(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppPalette.blue900,
      );

  /// headlineMedium (24px / w600 / h1.3) — Encabezados de sección y AppBar.
  static TextStyle get headlineMedium => _inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppPalette.blue900,
      );

  /// titleLarge (18px / w600 / h1.4) — Títulos de tarjetas y modales.
  static TextStyle get titleLarge => _inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppPalette.textPrimary,
      );

  /// bodyLarge (16px / w400 / h1.5) — Texto principal de lectura y campos de entrada.
  static TextStyle get bodyLarge => _inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppPalette.textPrimary,
      );

  /// bodyMedium (14px / w400 / h1.5) — Texto secundario y descripciones.
  static TextStyle get bodyMedium => _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppPalette.textSecondary,
      );

  /// labelSmall (12px / w500 / h1.4) — Etiquetas, chips y metadata (mínimo accesible).
  static TextStyle get labelSmall => _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppPalette.textSecondary,
      );

  // ═══════════════════════════════════════════════════════════
  // VARIANTES ESPECIALIZADAS (Tabular Figures para Contabilidad)
  // ═══════════════════════════════════════════════════════════

  /// Estilo numérico monetario con alineación tabular fija para columnas financieras.
  static TextStyle moneyStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppPalette.textPrimary,
  }) {
    return _inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Construye el TextTheme completo para ThemeData.
  static TextTheme createTextTheme() {
    return TextTheme(
      displayLarge: displayLarge,
      headlineMedium: headlineMedium,
      titleLarge: titleLarge,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      labelSmall: labelSmall,
    );
  }
}
