import 'package:flutter/cupertino.dart';

/// Catálogo centralizado de iconos del sistema Estilo Neutral.
/// REGLA ESTRICTA: Se utiliza ÚNICAMENTE CupertinoIcons.
/// Prohibido el uso de iconos del paquete Material.
abstract final class AppIcons {
  // ═══════════════════════════════════════════════════════════
  // TAMAÑOS NORMALIZADOS
  // ═══════════════════════════════════════════════════════════
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;

  // ═══════════════════════════════════════════════════════════
  // NAVEGACIÓN
  // ═══════════════════════════════════════════════════════════
  static const IconData home = CupertinoIcons.house;
  static const IconData back = CupertinoIcons.back;
  static const IconData forward = CupertinoIcons.forward;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData menu = CupertinoIcons.line_horizontal_3;

  // ═══════════════════════════════════════════════════════════
  // ENTIDADES DE DOMINIO
  // ═══════════════════════════════════════════════════════════
  static const IconData customer = CupertinoIcons.person;
  static const IconData customers = CupertinoIcons.person_2;
  static const IconData product = CupertinoIcons.cube_box;
  static const IconData products = CupertinoIcons.cube_box_fill;
  static const IconData sale = CupertinoIcons.cart;
  static const IconData purchase = CupertinoIcons.arrow_down_circle;
  static const IconData currency = CupertinoIcons.money_dollar;
  static const IconData rate = CupertinoIcons.chart_bar;

  // ═══════════════════════════════════════════════════════════
  // ACCIONES CRUD / OPERATIVAS
  // ═══════════════════════════════════════════════════════════
  static const IconData add = CupertinoIcons.add;
  static const IconData edit = CupertinoIcons.pencil;
  static const IconData delete = CupertinoIcons.trash;
  static const IconData save = CupertinoIcons.checkmark;
  static const IconData cancel = CupertinoIcons.xmark;
  static const IconData search = CupertinoIcons.search;
  static const IconData filter = CupertinoIcons.line_horizontal_3_decrease;
  static const IconData refresh = CupertinoIcons.arrow_clockwise;

  // ═══════════════════════════════════════════════════════════
  // REPORTES Y AUDITORÍA
  // ═══════════════════════════════════════════════════════════
  static const IconData summary = CupertinoIcons.doc_text;
  static const IconData audit = CupertinoIcons.shield_lefthalf_fill;
  static const IconData quarantine = CupertinoIcons.exclamationmark_triangle;
  static const IconData report = CupertinoIcons.doc_chart;
  static const IconData checklist = CupertinoIcons.checkmark_seal;

  // ═══════════════════════════════════════════════════════════
  // ESTADOS SEMÁNTICOS
  // ═══════════════════════════════════════════════════════════
  static const IconData success = CupertinoIcons.checkmark_circle;
  static const IconData warning = CupertinoIcons.exclamationmark_circle;
  static const IconData error = CupertinoIcons.xmark_circle;
  static const IconData info = CupertinoIcons.info_circle;
}
