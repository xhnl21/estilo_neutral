import 'package:flutter/material.dart';
import 'colors.dart';

/// Tokens de espaciado modular (base 4), radios y sombras sutiles.
abstract final class AppSpacing {
  // ═══════════════════════════════════════════════════════════
  // ESPACIADO (Base 4)
  // ═══════════════════════════════════════════════════════════
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // EdgeInsets de conveniencia
  static const EdgeInsets pXs = EdgeInsets.all(xs);
  static const EdgeInsets pSm = EdgeInsets.all(sm);
  static const EdgeInsets pMd = EdgeInsets.all(md);
  static const EdgeInsets pLg = EdgeInsets.all(lg);
  static const EdgeInsets pXl = EdgeInsets.all(xl);

  static const EdgeInsets pxMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets pxLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pySm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets pyMd = EdgeInsets.symmetric(vertical: md);

  // ═══════════════════════════════════════════════════════════
  // RADIOS
  // ═══════════════════════════════════════════════════════════
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusPill = 999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius roundedPill = BorderRadius.all(Radius.circular(radiusPill));

  // ═══════════════════════════════════════════════════════════
  // SOMBRAS (Minimalistas — preferir bordes sutiles)
  // ═══════════════════════════════════════════════════════════
  static const List<BoxShadow> shadowNone = [];

  static final List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: AppPalette.blue900.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowCard = [
    BoxShadow(
      color: AppPalette.blue900.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
