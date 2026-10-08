import 'package:equatable/equatable.dart';

import '../../../../models/config_notificaciones.dart';
import '../../../../models/organizacion.dart';

enum ConfigNotificacionesStatus { initial, loading, success, failure }

/// Campos validables del formulario de límites.
enum CampoConfigNotificaciones { limitePorUsuario, limiteOrganizacion }

/// Una organización con los límites que le rigen hoy.
class FilaConfigNotificaciones extends Equatable {
  final Organizacion organizacion;
  final ConfigNotificaciones config;

  /// Usuarios activos de la organización (comparten el límite de la organización).
  final int usuarios;

  const FilaConfigNotificaciones({required this.organizacion, required this.config, required this.usuarios});

  @override
  List<Object?> get props => [organizacion.id, organizacion.nombre, config, usuarios];
}

/// Estado inmutable de "Configuración de notificaciones".
class ConfigNotificacionesState extends Equatable {
  final ConfigNotificacionesStatus status;
  final List<FilaConfigNotificaciones> filas;
  final bool guardando;
  final Map<CampoConfigNotificaciones, String> erroresFormulario;

  /// Organización recién guardada (transitorio): el formulario se cierra.
  final String? guardadaOrganizacionId;
  final String? actionSuccessMessage;
  final String? errorMessage;

  const ConfigNotificacionesState({
    this.status = ConfigNotificacionesStatus.initial,
    this.filas = const [],
    this.guardando = false,
    this.erroresFormulario = const {},
    this.guardadaOrganizacionId,
    this.actionSuccessMessage,
    this.errorMessage,
  });

  ConfigNotificacionesState copyWith({
    ConfigNotificacionesStatus? status,
    List<FilaConfigNotificaciones>? filas,
    bool? guardando,
    Map<CampoConfigNotificaciones, String>? erroresFormulario,
    String? guardadaOrganizacionId,
    String? actionSuccessMessage,
    String? errorMessage,
  }) {
    return ConfigNotificacionesState(
      status: status ?? this.status,
      filas: filas ?? this.filas,
      guardando: guardando ?? this.guardando,
      erroresFormulario: erroresFormulario ?? this.erroresFormulario,
      // Transitorios: solo viven en la emisión que los trae.
      guardadaOrganizacionId: guardadaOrganizacionId,
      actionSuccessMessage: actionSuccessMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, filas, guardando, erroresFormulario, guardadaOrganizacionId, actionSuccessMessage, errorMessage];
}
