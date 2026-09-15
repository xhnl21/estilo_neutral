import 'package:flutter/material.dart';

/// Design tokens para la paleta cromática de Estilo Neutral.
/// Basado en los 5 colores inmutables y estándares WCAG 2.2 AA.
abstract final class AppPalette {
  // ═══════════════════════════════════════════════════════════
  // AZULES BASE (Inmutables — coincidencia exacta con la paleta)
  // ═══════════════════════════════════════════════════════════
  /// Azul profundo (#005187) — AppBar, headers, texto énfasis alto.
  /// Contraste sobre surface: ~8.5:1 (Cumple AAA).
  static const Color blue900 = Color(0xFF005187);

  /// Azul medio (#4D82BC) — Botones primarios, FAB, íconos activos.
  /// Contraste sobre surface: ~3.2:1 (AA Large / Elementos gráficos).
  static const Color blue700 = Color(0xFF4D82BC);
  static const Color primary = blue700;

  /// Azul claro (#84B6F4) — Hover/pressed, chips secundarios, acentos.
  /// Contraste sobre surface: ~2.1:1 (Solo decorativo/fondos).
  static const Color blue400 = Color(0xFF84B6F4);

  /// Azul muy claro (#C4DAFA) — Fondos de tarjetas, contenedores de sección.
  static const Color blue100 = Color(0xFFC4DAFA);

  /// Blanco azulado (#FCFFFF) — Superficie pura / fondo principal de pantallas.
  static const Color surface = Color(0xFFFCFFFF);

  // ═══════════════════════════════════════════════════════════
  // NEUTROS DERIVADOS (Mínimos para jerarquía tipográfica y bordes)
  // ═══════════════════════════════════════════════════════════
  /// Texto principal (#0A1F33) — Máximo contraste (~15:1 sobre surface).
  static const Color textPrimary = Color(0xFF0A1F33);

  /// Texto secundario (#4A5A6B) — Subtítulos, labels y metadata (~6:1 sobre surface).
  static const Color textSecondary = Color(0xFF4A5A6B);

  /// Texto deshabilitado (#9AA7B4).
  static const Color textDisabled = Color(0xFF9AA7B4);

  /// Bordes limpios (#D6E2F0) — Preferencia minimalista antes que sombras pesadas.
  static const Color border = Color(0xFFD6E2F0);

  /// Divisores sutiles (#E8F0F9).
  static const Color divider = Color(0xFFE8F0F9);

  // ═══════════════════════════════════════════════════════════
  // SEMÁNTICOS (Accesibles sobre surface #FCFFFF)
  // ═══════════════════════════════════════════════════════════
  /// Éxito contable / abonos (#2E7D5B) — Contraste ~5.2:1.
  static const Color success = Color(0xFF2E7D5B);

  /// Advertencia / alertas de saldo (#B26A00) — Contraste ~4.7:1.
  static const Color warning = Color(0xFFB26A00);

  /// Error / deudas pendientes (#B3261E) — Contraste ~5.5:1.
  static const Color error = Color(0xFFB3261E);

  /// Informativo (#005187) — Reutiliza primario oscuro.
  static const Color info = Color(0xFF005187);
}
