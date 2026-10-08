import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../models/plantilla_notificacion.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import 'plantillas_notificacion_state.dart';

/// Listado de notificaciones guardadas para reutilizar (hoja
/// "plantillas_notificacion"): filtro por tipo y eliminación. El alta y la
/// edición viven en [PlantillaFormCubit]; el envío, en EnviarNotificacionCubit.
class PlantillasNotificacionCubit extends Cubit<PlantillasNotificacionState> {
  final SheetsDataService dataService;

  PlantillasNotificacionCubit({required this.dataService}) : super(const PlantillasNotificacionState()) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final plantillas = List.of(dataService.plantillasNotificacion)
      ..sort((a, b) => b.actualizadoEn.compareTo(a.actualizadoEn));
    final tipos = List.of(dataService.tiposNotificacion);
    final filtro = state.filtroTipoId;
    emit(state.copyWith(
      status: dataService.isLoading ? PlantillasNotificacionStatus.loading : PlantillasNotificacionStatus.success,
      plantillas: plantillas,
      tipos: tipos,
      // Si el tipo filtrado desapareció del catálogo, se vuelve a "Todos".
      limpiarFiltro: filtro != null && !tipos.any((t) => t.id == filtro),
    ));
  }

  /// Filtra por [tipoId]; `null` muestra todas.
  void filtrarPorTipo(String? tipoId) {
    emit(tipoId == null ? state.copyWith(limpiarFiltro: true) : state.copyWith(filtroTipoId: tipoId));
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: PlantillasNotificacionStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> eliminar(PlantillaNotificacion plantilla) async {
    try {
      await dataService.deletePlantillaNotificacion(plantilla.id);
      if (isClosed) return;
      emit(state.copyWith(actionSuccessMessage: 'Se eliminó "${plantilla.titulo}".'));
    } catch (e, st) {
      Logger.error('PlantillasNotificacionCubit: no se pudo eliminar ${plantilla.id}', e, st);
      if (isClosed) return;
      emit(state.copyWith(errorMessage: switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => '$message',
        _ => 'No se pudo eliminar: $e',
      }));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
