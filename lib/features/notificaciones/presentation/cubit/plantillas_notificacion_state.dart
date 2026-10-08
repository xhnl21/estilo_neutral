import 'package:equatable/equatable.dart';

import '../../../../models/plantilla_notificacion.dart';

enum PlantillasNotificacionStatus { initial, loading, success, failure }

/// Estado del listado de notificaciones guardadas (para reutilizar).
class PlantillasNotificacionState extends Equatable {
  final PlantillasNotificacionStatus status;

  /// Las de la organización actual, más recientes primero.
  final List<PlantillaNotificacion> plantillas;
  final List<TipoNotificacion> tipos;

  /// Tipo por el que se filtra; `null` = todos.
  final String? filtroTipoId;

  final String? actionSuccessMessage;
  final String? errorMessage;

  const PlantillasNotificacionState({
    this.status = PlantillasNotificacionStatus.initial,
    this.plantillas = const [],
    this.tipos = const [],
    this.filtroTipoId,
    this.actionSuccessMessage,
    this.errorMessage,
  });

  List<PlantillaNotificacion> get filtradas =>
      filtroTipoId == null ? plantillas : plantillas.where((p) => p.tipoId == filtroTipoId).toList();

  String nombreTipo(String tipoId) => tipos.where((t) => t.id == tipoId).firstOrNull?.nombre ?? 'Sin tipo';

  /// Tipos que tienen al menos una notificación guardada, con cuántas (para
  /// los filtros).
  Map<String, int> get cantidadPorTipo {
    final conteo = <String, int>{};
    for (final p in plantillas) {
      conteo[p.tipoId] = (conteo[p.tipoId] ?? 0) + 1;
    }
    return conteo;
  }

  PlantillasNotificacionState copyWith({
    PlantillasNotificacionStatus? status,
    List<PlantillaNotificacion>? plantillas,
    List<TipoNotificacion>? tipos,
    String? filtroTipoId,
    bool limpiarFiltro = false,
    String? actionSuccessMessage,
    String? errorMessage,
  }) {
    return PlantillasNotificacionState(
      status: status ?? this.status,
      plantillas: plantillas ?? this.plantillas,
      tipos: tipos ?? this.tipos,
      filtroTipoId: limpiarFiltro ? null : (filtroTipoId ?? this.filtroTipoId),
      // Transitorios: solo viven en la emisión que los trae.
      actionSuccessMessage: actionSuccessMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, plantillas, tipos, filtroTipoId, actionSuccessMessage, errorMessage];
}
