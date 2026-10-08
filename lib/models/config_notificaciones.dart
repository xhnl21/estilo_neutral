import 'package:equatable/equatable.dart';

import 'fila_hoja.dart';

/// Período en el que se cuentan los envíos de notificaciones. Es de
/// calendario, en hora de Venezuela: el día empieza a las 00:00, la semana
/// el lunes y el mes el día 1 (lo calcula el Apps Script).
enum PeriodoNotificaciones {
  hora('hora', 'Por hora', 'esta hora'),
  dia('dia', 'Por día', 'hoy'),
  semana('semana', 'Por semana', 'esta semana'),
  mes('mes', 'Por mes', 'este mes');

  /// Valor en la hoja.
  final String valor;
  final String etiqueta;

  /// "Te quedan 3 [enElPeriodo]".
  final String enElPeriodo;

  const PeriodoNotificaciones(this.valor, this.etiqueta, this.enElPeriodo);

  static PeriodoNotificaciones? desde(String valor) {
    final v = valor.trim().toLowerCase();
    for (final p in values) {
      if (p.valor == v) return p;
    }
    return null;
  }
}

/// Límites de envío de notificaciones de una organización (hoja
/// `config_notificaciones`, una fila por organización). Un límite en 0 es
/// "sin límite". Una organización sin fila usa [ConfigNotificaciones.porDefecto].
///
/// | A id | B organizacion_id | C periodo | D limite_por_usuario |
/// | E limite_organizacion | F actualizado_en | G actualizado_por |
class ConfigNotificaciones extends Equatable {
  /// Formato `cn00000001` (lo genera el servidor); vacío si la organización
  /// todavía no tiene fila.
  final String id;
  final String organizacionId;
  final PeriodoNotificaciones periodo;

  /// Envíos por usuario en el período (0 = sin límite).
  final int limitePorUsuario;

  /// Envíos de todos los usuarios de la organización en el período (0 = sin límite).
  final int limiteOrganizacion;

  /// Lo escribe el servidor al guardar.
  final String actualizadoEn;
  final String actualizadoPor;

  /// Valores que aplica el servidor a una organización sin fila
  /// (CONFIG_NOTIFICACIONES_DEFECTO en google_apps_script.js).
  static const periodoPorDefecto = PeriodoNotificaciones.hora;
  static const limitePorUsuarioPorDefecto = 30;
  static const limiteOrganizacionPorDefecto = 0;

  /// Máximo aceptado por el servidor (LIMITE_NOTIFICACIONES_MAXIMO).
  static const limiteMaximo = 100000;

  const ConfigNotificaciones({
    required this.id,
    required this.organizacionId,
    required this.periodo,
    required this.limitePorUsuario,
    required this.limiteOrganizacion,
    this.actualizadoEn = '',
    this.actualizadoPor = '',
  });

  /// Lo que rige para [organizacionId] mientras no tenga fila propia.
  const ConfigNotificaciones.porDefecto(this.organizacionId)
      : id = '',
        periodo = periodoPorDefecto,
        limitePorUsuario = limitePorUsuarioPorDefecto,
        limiteOrganizacion = limiteOrganizacionPorDefecto,
        actualizadoEn = '',
        actualizadoPor = '';

  bool get esPorDefecto => id.isEmpty;

  /// Fila de la hoja. Un período o un límite ilegibles se toman como los de
  /// por defecto, igual que hace el servidor al contar.
  factory ConfigNotificaciones.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'cn');
    int? limite(int i) {
      final n = num.tryParse(f.texto(i));
      return n != null && n >= 0 ? n.floor() : null;
    }

    return ConfigNotificaciones(
      id: f.id,
      organizacionId: f.texto(0),
      periodo: PeriodoNotificaciones.desde(f.texto(1)) ?? periodoPorDefecto,
      limitePorUsuario: limite(2) ?? limitePorUsuarioPorDefecto,
      limiteOrganizacion: limite(3) ?? limiteOrganizacionPorDefecto,
      actualizadoEn: f.texto(4),
      actualizadoPor: f.texto(5),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizacion_id': organizacionId,
        'periodo': periodo.valor,
        'limite_por_usuario': limitePorUsuario,
        'limite_organizacion': limiteOrganizacion,
        'actualizado_por': actualizadoPor,
      };

  ConfigNotificaciones copyWith({
    String? id,
    PeriodoNotificaciones? periodo,
    int? limitePorUsuario,
    int? limiteOrganizacion,
    String? actualizadoEn,
    String? actualizadoPor,
  }) =>
      ConfigNotificaciones(
        id: id ?? this.id,
        organizacionId: organizacionId,
        periodo: periodo ?? this.periodo,
        limitePorUsuario: limitePorUsuario ?? this.limitePorUsuario,
        limiteOrganizacion: limiteOrganizacion ?? this.limiteOrganizacion,
        actualizadoEn: actualizadoEn ?? this.actualizadoEn,
        actualizadoPor: actualizadoPor ?? this.actualizadoPor,
      );

  @override
  List<Object?> get props =>
      [id, organizacionId, periodo, limitePorUsuario, limiteOrganizacion, actualizadoEn, actualizadoPor];
}

/// Uso del período actual para el usuario de la sesión (acción
/// `uso_notificaciones` del Apps Script).
class UsoNotificaciones extends Equatable {
  final PeriodoNotificaciones periodo;
  final int limitePorUsuario;
  final int limiteOrganizacion;
  final int usadosUsuario;
  final int usadosOrganizacion;

  /// Cuándo empieza el período siguiente.
  final DateTime? renueva;

  const UsoNotificaciones({
    required this.periodo,
    required this.limitePorUsuario,
    required this.limiteOrganizacion,
    required this.usadosUsuario,
    required this.usadosOrganizacion,
    this.renueva,
  });

  /// Envíos que le quedan al usuario en el período: el menor entre su cupo y
  /// el de la organización. `null` = sin límite.
  int? get restantes {
    final candidatos = [
      if (limitePorUsuario > 0) limitePorUsuario - usadosUsuario,
      if (limiteOrganizacion > 0) limiteOrganizacion - usadosOrganizacion,
    ];
    if (candidatos.isEmpty) return null;
    final r = candidatos.reduce((a, b) => a < b ? a : b);
    return r < 0 ? 0 : r;
  }

  /// Por qué no quedan envíos, o `null` si quedan (o no hay límite).
  String? get motivoAgotado {
    if (restantes != 0) return null;
    final porUsuario = limitePorUsuario > 0 && usadosUsuario >= limitePorUsuario;
    final base = porUsuario
        ? 'Llegaste a tu límite de $limitePorUsuario notificaciones ${periodo.enElPeriodo}.'
        : 'Tu organización llegó a su límite de $limiteOrganizacion notificaciones ${periodo.enElPeriodo}.';
    return '$base${textoRenueva()}';
  }

  /// " Se renueva el 09/10 a las 00:00." (hora del teléfono), o vacío.
  String textoRenueva() {
    final r = renueva;
    if (r == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return ' Se renueva el ${dos(r.day)}/${dos(r.month)} a las ${dos(r.hour)}:${dos(r.minute)}.';
  }

  @override
  List<Object?> get props =>
      [periodo, limitePorUsuario, limiteOrganizacion, usadosUsuario, usadosOrganizacion, renueva];
}
