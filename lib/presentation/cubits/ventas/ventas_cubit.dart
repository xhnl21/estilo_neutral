import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/cliente.dart';
import '../../../models/enums.dart';
import '../../../models/venta.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'ventas_state.dart';

/// Cubit para gestión de estado reactivo del módulo de Ventas.
class VentasCubit extends Cubit<VentasState> {
  final SheetsDataService dataService;

  VentasCubit({
    required this.dataService,
    String? initialClienteId,
  }) : super(VentasState(filtroClienteId: initialClienteId)) {
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
    final allVentas = List<Venta>.from(dataService.ventas);
    final allClientes = List<Cliente>.from(dataService.clientes);
    final filtered = _applyFilters(allVentas, state.filtroClienteId, state.filterStatus);
    emit(state.copyWith(
      status: dataService.isLoading ? VentasStatus.loading : VentasStatus.success,
      ventas: allVentas,
      filteredVentas: filtered,
      clientes: allClientes,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<Venta> _applyFilters(List<Venta> list, String? clienteId, String filterStatus) {
    return list.where((v) {
      if (clienteId != null && v.clienteId != clienteId) return false;
      if (filterStatus == 'Pagada') return v.estado == EstadoVenta.pagada;
      if (filterStatus == 'Pendiente') return v.estado == EstadoVenta.pendiente;
      return true;
    }).toList();
  }

  void setFilterStatus(String status) {
    Logger.debug('VentasCubit: Cambiando filtro de estado a: $status');
    final filtered = _applyFilters(state.ventas, state.filtroClienteId, status);
    emit(state.copyWith(
      filterStatus: status,
      filteredVentas: filtered,
    ));
  }

  void setFiltroCliente(String? clienteId) {
    Logger.debug('VentasCubit: Cambiando filtro de cliente a: $clienteId');
    final filtered = _applyFilters(state.ventas, clienteId, state.filterStatus);
    emit(state.copyWith(
      filtroClienteId: clienteId,
      clearFiltroCliente: clienteId == null,
      filteredVentas: filtered,
    ));
  }

  void clearFiltroCliente() {
    setFiltroCliente(null);
  }

  /// Registra una venta en un lote atómico (All-or-Nothing).
  Future<bool> registrarVentaAtomica({
    required String clienteId,
    required List<({String productoId, int cantidad, double precioUsd})> items,
    required String metodoPagoId,
    double comisionPagoMovilBs = 0.0,
    required double abonoUsd,
    bool usarTasaManual = false,
  }) async {
    emit(state.copyWith(status: VentasStatus.loading));
    try {
      final success = await dataService.addVentaAtomica(
        clienteId: clienteId,
        items: items,
        metodoPagoId: metodoPagoId,
        comisionPagoMovilBs: comisionPagoMovilBs,
        abonoUsd: abonoUsd,
        usarTasaManual: usarTasaManual,
      );

      if (success) {
        emit(state.copyWith(
          status: VentasStatus.success,
          actionSuccessMessage: 'Venta registrada con éxito en lote atómico',
        ));
        _syncFromService();
        return true;
      } else {
        emit(state.copyWith(
          status: VentasStatus.failure,
          errorMessage: 'Error al registrar venta: la transacción fue abortada en el servidor',
        ));
        return false;
      }
    } catch (e) {
      emit(state.copyWith(
        status: VentasStatus.failure,
        errorMessage: 'Excepción en transacción de venta: $e',
      ));
      return false;
    }
  }

  Future<void> refresh() async {
    Logger.info('VentasCubit: Refrescando ventas desde Google Sheets...');
    emit(state.copyWith(status: VentasStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
