import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/metodo_pago.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'metodos_pago_state.dart';

/// Cubit para gestión de estado del módulo de Métodos de Pago.
class MetodosPagoCubit extends Cubit<MetodosPagoState> {
  final SheetsDataService dataService;

  MetodosPagoCubit({required this.dataService}) : super(const MetodosPagoState()) {
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
    final currentList = List<MetodoPago>.from(dataService.metodosPago);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? MetodosPagoStatus.loading : MetodosPagoStatus.success,
      metodos: currentList,
      filteredMetodos: filtered,
      totalActivos: dataService.metodosPagoActivos.length,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<MetodoPago> _filter(List<MetodoPago> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((m) {
      return m.nombre.toLowerCase().contains(q) || m.id.toLowerCase().contains(q);
    }).toList();
  }

  void search(String query) {
    final filtered = _filter(state.metodos, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredMetodos: filtered,
    ));
  }

  Future<void> refresh() async {
    Logger.info('MetodosPagoCubit: Refrescando métodos de pago desde Google Sheets...');
    emit(state.copyWith(status: MetodosPagoStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addMetodoPago(String nombre) async {
    emit(state.copyWith(status: MetodosPagoStatus.loading));
    await dataService.addMetodoPago(nombre: nombre);
    emit(state.copyWith(
      status: MetodosPagoStatus.success,
      actionSuccessMessage: 'Método de pago "$nombre" registrado con éxito.',
    ));
    _syncFromService();
  }

  Future<bool> toggleMetodoPagoStatus(String id) async {
    final ok = await dataService.toggleMetodoPagoStatus(id);
    _syncFromService();
    return ok;
  }

  Future<bool> deleteMetodoPago(String id) async {
    final ok = await dataService.deleteMetodoPago(id);
    _syncFromService();
    return ok;
  }

  bool isMetodoPagoEnUso(String id) => dataService.isMetodoPagoEnUso(id);

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
