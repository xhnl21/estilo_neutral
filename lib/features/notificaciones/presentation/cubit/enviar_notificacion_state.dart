import 'package:equatable/equatable.dart';

import '../../../../models/config_notificaciones.dart';
import '../../../../models/organizacion.dart';
import '../../../../models/plantilla_notificacion.dart';
import '../../../../models/usuario.dart';
import '../../domain/destino_notificacion.dart';

enum EnviarNotificacionStatus { editando, enviando, enviada, error }

/// Campos validables del formulario.
enum CampoNotificacion { titulo, cuerpo, destino }

/// Estado inmutable de la pantalla "Enviar notificación".
class EnviarNotificacionState extends Equatable {
  final EnviarNotificacionStatus status;
  final AlcanceNotificacion alcance;
  final List<Organizacion> organizaciones;

  /// Usuarios con acceso, agrupados por la organización a la que pertenecen.
  final Map<String, List<Usuario>> usuariosPorOrganizacion;

  final Set<String> organizacionesSeleccionadas;
  final Set<String> usuariosSeleccionados;
  final Map<CampoNotificacion, String> errores;

  /// Resultado del último envío (transitorio).
  final String? mensaje;

  /// Límites y uso del período del usuario de la sesión; `null` mientras no
  /// se pudo consultar (sin conexión): el servidor igual aplica el límite.
  final UsoNotificaciones? uso;

  /// Se agotó el cupo (transitorio): la vista muestra un diálogo con este motivo.
  final String? avisoCupo;

  /// Notificación guardada que se está viendo/enviando; `null` si se borró
  /// (o desde otro teléfono) mientras estaba abierta.
  final PlantillaNotificacion? plantilla;
  final String nombreTipo;

  const EnviarNotificacionState({
    this.status = EnviarNotificacionStatus.editando,
    this.alcance = AlcanceNotificacion.organizaciones,
    this.organizaciones = const [],
    this.usuariosPorOrganizacion = const {},
    this.organizacionesSeleccionadas = const {},
    this.usuariosSeleccionados = const {},
    this.errores = const {},
    this.mensaje,
    this.uso,
    this.avisoCupo,
    this.plantilla,
    this.nombreTipo = '',
  });

  bool get enviando => status == EnviarNotificacionStatus.enviando;

  /// Ya no le quedan envíos en el período.
  bool get sinCupo => uso?.restantes == 0;

  DestinoNotificacion get destino => switch (alcance) {
        AlcanceNotificacion.global => const DestinoNotificacion.global(),
        AlcanceNotificacion.organizaciones => DestinoNotificacion.organizaciones(organizacionesSeleccionadas),
        AlcanceNotificacion.usuarios => DestinoNotificacion.usuarios(usuariosSeleccionados),
      };

  EnviarNotificacionState copyWith({
    EnviarNotificacionStatus? status,
    AlcanceNotificacion? alcance,
    List<Organizacion>? organizaciones,
    Map<String, List<Usuario>>? usuariosPorOrganizacion,
    Set<String>? organizacionesSeleccionadas,
    Set<String>? usuariosSeleccionados,
    Map<CampoNotificacion, String>? errores,
    String? mensaje,
    UsoNotificaciones? uso,
    String? avisoCupo,
    PlantillaNotificacion? plantilla,
    bool sinPlantilla = false,
    String? nombreTipo,
  }) {
    return EnviarNotificacionState(
      status: status ?? this.status,
      alcance: alcance ?? this.alcance,
      organizaciones: organizaciones ?? this.organizaciones,
      usuariosPorOrganizacion: usuariosPorOrganizacion ?? this.usuariosPorOrganizacion,
      organizacionesSeleccionadas: organizacionesSeleccionadas ?? this.organizacionesSeleccionadas,
      usuariosSeleccionados: usuariosSeleccionados ?? this.usuariosSeleccionados,
      errores: errores ?? this.errores,
      mensaje: mensaje,
      uso: uso ?? this.uso,
      avisoCupo: avisoCupo,
      plantilla: sinPlantilla ? null : (plantilla ?? this.plantilla),
      nombreTipo: nombreTipo ?? this.nombreTipo,
    );
  }

  @override
  List<Object?> get props => [
        status,
        alcance,
        organizaciones.map((o) => '${o.id}|${o.nombre}').join(','),
        usuariosPorOrganizacion.map((k, v) => MapEntry(k, v.map((u) => u.email).join(','))),
        organizacionesSeleccionadas.toList()..sort(),
        usuariosSeleccionados.toList()..sort(),
        errores,
        mensaje,
        uso,
        avisoCupo,
        plantilla,
        nombreTipo,
      ];
}
