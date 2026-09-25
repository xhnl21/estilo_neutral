import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/tasa_registro.dart';
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
    final list = List<TasaRegistro>.from(dataService.tasas)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final usdVigente = dataService.tasaBcvVigente('USD');
    final eurVigente = dataService.tasaBcvVigente('EUR');
    final orgId = dataService.currentOrganizacionId ?? '';
    final monedaActual = dataService.monedaOrganizacion(orgId);

    emit(state.copyWith(
      status: dataService.isLoading ? TasasStatus.loading : TasasStatus.success,
      tasas: list,
      usdVigente: usdVigente,
      eurVigente: eurVigente,
      monedaActual: monedaActual,
      errorMessage: dataService.errorMessage,
    ));
  }

  Future<void> refresh() async {
    Logger.info('TasasCubit: Refrescando tasas desde Google Sheets...');
    emit(state.copyWith(status: TasasStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> obtenerTasaDeHoy() async {
    Logger.info('TasasCubit: Solicitando refresco de tasa de hoy...');
    emit(state.copyWith(isActualizandoTasaHoy: true));
    final ok = await dataService.refrescarTasaHoy();
    emit(state.copyWith(
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
