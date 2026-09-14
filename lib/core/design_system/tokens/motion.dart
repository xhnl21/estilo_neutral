import 'package:flutter/animation.dart';

/// Tokens de movimiento y transiciones minimalistas.
/// Prohibidas animaciones decorativas o de rebote; solo para cambio de estado.
abstract final class AppMotion {
  // ═══════════════════════════════════════════════════════════
  // DURACIONES
  // ═══════════════════════════════════════════════════════════
  /// 150ms — Micro-interacciones (feedback de botón, cambios de chip).
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — Transiciones entre pestañas o vistas.
  static const Duration normal = Duration(milliseconds: 250);

  /// 400ms — Despliegue de diálogos modales o paneles inferiores.
  static const Duration slow = Duration(milliseconds: 400);

  // ═══════════════════════════════════════════════════════════
  // CURVAS
  // ═══════════════════════════════════════════════════════════
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve standard = Curves.easeInOut;
}
