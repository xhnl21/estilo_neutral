import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../../../models/config_notificaciones.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import 'config_notificaciones_state.dart';

/// Cubit de "Configuración de notificaciones": límites de envío por
/// organización (hoja "config_notificaciones"). Los aplica el Apps Script
/// al enviar; acá solo se editan.
class ConfigNotificacionesCubit extends Cubit<ConfigNotificacionesState> {
  final SheetsDataService dataService;

  ConfigNotificacionesCubit({required this.dataService}) : super(const ConfigNotificacionesState()) {
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
    final usuariosPorOrg = <String, int>{};
    for (final u in dataService.usuarios.where((u) => u.activo)) {
      final org = dataService.organizacionIdForUsuario(u.email);
      if (org != null) usuariosPorOrg[org] = (usuariosPorOrg[org] ?? 0) + 1;
    }
    final organizaciones = List.of(dataService.organizaciones)..sort((a, b) => a.nombre.compareTo(b.nombre));
    emit(state.copyWith(
      status: dataService.isLoading ? ConfigNotificacionesStatus.loading : ConfigNotificacionesStatus.success,
      filas: [
        for (final o in organizaciones)
          FilaConfigNotificaciones(
            organizacion: o,
            config: dataService.configNotificacionesDe(o.id),
            usuarios: usuariosPorOrg[o.id] ?? 0,
          ),
      ],
    ));
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: ConfigNotificacionesStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Al abrir el formulario: sin errores de una edición anterior.
  void abrirFormulario() => emit(state.copyWith(erroresFormulario: const {}));

  /// Limpia el error de un campo cuando se lo vuelve a editar.
  void campoEditado(CampoConfigNotificaciones campo) {
    if (!state.erroresFormulario.containsKey(campo)) return;
    emit(state.copyWith(erroresFormulario: Map.of(state.erroresFormulario)..remove(campo)));
  }

  static String? _errorLimite(String texto) {
    final n = int.tryParse(texto.trim());
    if (n == null) return 'Escribí un número entero (0 = sin límite).';
    if (n < 0 || n > ConfigNotificaciones.limiteMaximo) {
      return 'De 0 (sin límite) a ${ConfigNotificaciones.limiteMaximo}.';
    }
    return null;
  }

  Future<void> guardar({
    required String organizacionId,
    required PeriodoNotificaciones periodo,
    required String limitePorUsuario,
    required String limiteOrganizacion,
  }) async {
    if (state.guardando) return;
    final errores = <CampoConfigNotificaciones, String>{
      if (_errorLimite(limitePorUsuario) case final e?) CampoConfigNotificaciones.limitePorUsuario: e,
      if (_errorLimite(limiteOrganizacion) case final e?) CampoConfigNotificaciones.limiteOrganizacion: e,
    };
    if (errores.isNotEmpty) {
      emit(state.copyWith(erroresFormulario: errores));
      return;
    }
    emit(state.copyWith(guardando: true, erroresFormulario: const {}));
    try {
      await dataService.guardarConfigNotificaciones(
        organizacionId: organizacionId,
        periodo: periodo,
        limitePorUsuario: int.parse(limitePorUsuario.trim()),
        limiteOrganizacion: int.parse(limiteOrganizacion.trim()),
      );
      if (isClosed) return;
      final nombre = state.filas.where((f) => f.organizacion.id == organizacionId).firstOrNull?.organizacion.nombre;
      emit(state.copyWith(
        guardando: false,
        guardadaOrganizacionId: organizacionId,
        actionSuccessMessage: 'Límites de ${nombre ?? 'la organización'} guardados.',
      ));
    } catch (e, st) {
      Logger.error('ConfigNotificacionesCubit: no se pudieron guardar los límites', e, st);
      if (isClosed) return;
      emit(state.copyWith(
        guardando: false,
        errorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => '$message',
          _ => 'No se pudieron guardar los límites: $e',
        },
      ));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
