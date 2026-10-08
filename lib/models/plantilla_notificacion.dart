import 'package:equatable/equatable.dart';

import 'fila_hoja.dart';

/// Tipo de notificación (hoja `tipos_notificacion`, catálogo común a todas
/// las organizaciones): Pago quincenal, Cumpleaños, Reunión…
///
/// | A id | B nombre | C status |
class TipoNotificacion extends Equatable {
  /// Formato `tn00000001` (lo genera el servidor).
  final String id;
  final String nombre;
  final bool activo;

  const TipoNotificacion({required this.id, required this.nombre, this.activo = true});

  factory TipoNotificacion.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'tn');
    return TipoNotificacion(id: f.id, nombre: f.texto(0), activo: estadoActivo(f.texto(1)));
  }

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'status': activo};

  @override
  List<Object?> get props => [id, nombre, activo];
}

/// Notificación guardada para reutilizar (hoja `plantillas_notificacion`):
/// un tipo, un título y un mensaje. Cada organización ve las suyas. Al
/// enviarla se eligen los destinatarios.
///
/// | A id | B organizacion_id | C tipo_id | D titulo | E cuerpo |
/// | F creado_por | G actualizado_en |
class PlantillaNotificacion extends Equatable {
  /// Formato `pn00000001` (lo genera el servidor); vacío hasta que confirma.
  final String id;
  final String organizacionId;
  final String tipoId;
  final String titulo;
  final String cuerpo;

  /// Email de quien la creó y fecha del último cambio (ISO); los escribe el servidor.
  final String creadoPor;
  final String actualizadoEn;

  /// Límites del servidor (y de FCM) para título y mensaje.
  static const maxTitulo = 100;
  static const maxCuerpo = 500;

  const PlantillaNotificacion({
    required this.id,
    required this.organizacionId,
    required this.tipoId,
    required this.titulo,
    required this.cuerpo,
    this.creadoPor = '',
    this.actualizadoEn = '',
  });

  factory PlantillaNotificacion.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'pn');
    return PlantillaNotificacion(
      id: f.id,
      organizacionId: f.texto(0),
      tipoId: f.texto(1),
      // La comilla inicial es la que pone el servidor a un texto que
      // empieza con =, +, - o @ (para que Sheets no lo tome como fórmula).
      titulo: f.texto(2).replaceFirst(RegExp("^'"), ''),
      cuerpo: f.crudo(3).trim().replaceFirst(RegExp("^'"), ''),
      creadoPor: f.texto(4),
      actualizadoEn: f.texto(5),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizacion_id': organizacionId,
        'tipo_id': tipoId,
        'titulo': titulo,
        'cuerpo': cuerpo,
        'creado_por': creadoPor,
      };

  PlantillaNotificacion copyWith({String? id, String? tipoId, String? titulo, String? cuerpo, String? actualizadoEn}) =>
      PlantillaNotificacion(
        id: id ?? this.id,
        organizacionId: organizacionId,
        tipoId: tipoId ?? this.tipoId,
        titulo: titulo ?? this.titulo,
        cuerpo: cuerpo ?? this.cuerpo,
        creadoPor: creadoPor,
        actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      );

  @override
  List<Object?> get props => [id, organizacionId, tipoId, titulo, cuerpo, creadoPor, actualizadoEn];
}
