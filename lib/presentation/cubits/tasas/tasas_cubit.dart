import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'tasas_state.dart';

/// Cubit para gestión de estado del módulo de Tasas (arquitectura BLoC).
class TasasCubit extends Cubit<TasasState> {
  final SheetsDataService dataService;

  TasasCubit({required this.dataService}) : super(const TasasState()) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    _syncFromService();
  }

  void _syncFromService() {
    if (isClosed) return;
    final orgId = dataService.currentOrganizacionId ?? '';
    // Las tasas BCV son de todos; las manuales, solo de la organización actual.
    final list = dataService.tasas
        .where((t) => t.fuente != 'manual' || t.organizacionId == orgId)
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    // Estado armado completo (no copyWith): las tasas vigentes y la moneda
    // pueden volver a null si dejaron de existir.
    emit(TasasState(
      status: dataService.isLoading ? TasasStatus.loading : TasasStatus.success,
      tasas: list,
      usdVigente: dataService.tasaBcvVigente('USD'),
      eurVigente: dataService.tasaBcvVigente('EUR'),
      monedaActual: orgId.isEmpty ? null : dataService.monedaOrganizacion(orgId),
      isActualizandoTasaHoy: state.isActualizandoTasaHoy,
      actionSuccess: state.actionSuccess,
      errorMessage: dataService.errorMessage,
    ));
  }

  Future<void> refresh() async {
    Logger.info('TasasCubit: Refrescando tasas desde Google Sheets...');
    emit(state.copyWith(status: TasasStatus.loading, errorMessage: state.errorMessage));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Cambia la moneda base de la organización. Si Sheets no lo confirma se
  /// revierte (la pantalla vuelve a la moneda anterior) y se avisa.
  Future<void> cambiarMoneda(String organizacionId, String moneda) async {
    try {
      await dataService.setMonedaOrganizacion(organizacionId, moneda);
      if (isClosed) return;
      emit(state.copyWith(
          actionMessage: 'Moneda base cambiada a $moneda.', actionSuccess: true, errorMessage: state.errorMessage));
    } on StateError catch (e) {
      if (isClosed) return;
      emit(state.copyWith(actionMessage: e.message, actionSuccess: false, errorMessage: state.errorMessage));
    }
  }

  Future<void> obtenerTasaDeHoy() async {
    Logger.info('TasasCubit: Solicitando refresco de tasa de hoy...');
    emit(state.copyWith(isActualizandoTasaHoy: true, errorMessage: state.errorMessage));
    final ok = await dataService.refrescarTasaHoy();
    // El usuario pudo salir de la pantalla mientras se esperaba.
    if (isClosed) return;
    emit(state.copyWith(
      errorMessage: state.errorMessage,
      isActualizandoTasaHoy: false,
      actionMessage: ok
          ? 'Tasa de hoy obtenida correctamente.'
          : 'No se pudo obtener la tasa de hoy. Probá de nuevo en un momento.',
      actionSuccess: ok,
    ));
    _syncFromService();
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
