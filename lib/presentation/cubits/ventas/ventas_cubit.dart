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
    // Si el cliente filtrado fue eliminado, se quita el filtro: el select ya
    // no tiene esa opción. Mientras carga no se toca (la lista puede estar
    // vacía todavía y el filtro venir de la URL).
    final filtroHuerfano = !dataService.isLoading &&
        state.filtroClienteId != null &&
        !allClientes.any((c) => c.id == state.filtroClienteId);
    final filtroClienteId = filtroHuerfano ? null : state.filtroClienteId;
    final filtered = _applyFilters(allVentas, filtroClienteId, state.filterStatus);
    emit(state.copyWith(
      status: dataService.isLoading ? VentasStatus.loading : VentasStatus.success,
      ventas: allVentas,
      filteredVentas: filtered,
      clientes: allClientes,
      clearFiltroCliente: filtroHuerfano,
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

  void toggleExpanded(String ventaId) {
    if (state.expandedVentaId == ventaId) {
      emit(state.copyWith(clearExpandedId: true));
    } else {
      emit(state.copyWith(expandedVentaId: ventaId));
    }
  }

  /// Registra una venta en un lote atómico (All-or-Nothing).
  Future<bool> registrarVentaAtomica({
    required String clienteId,
    required List<({String productoId, int cantidad, double precioUsd})> items,
    required String metodoPagoId,
    double comisionPagoMovilBs = 0.0,
    required double abonoUsd,
    bool usarTasaManual = false,
  }) =>
      _ejecutar(
        () => dataService.addVenta(
          clienteId: clienteId,
          items: items,
          metodoPagoId: metodoPagoId,
          comisionPagoMovilBs: comisionPagoMovilBs,
          abonoUsd: abonoUsd,
          usarTasaManual: usarTasaManual,
        ),
        exito: 'Venta registrada con éxito en lote atómico',
      );

  /// Anula la venta (lote atómico: borra cabecera, ítems y abonos y repone
  /// el stock, o no toca nada).
  Future<bool> anularVenta(String id) => _ejecutar(
        () => dataService.deleteVenta(id),
        exito: 'Venta anulada y stock repuesto.',
      );

  Future<bool> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (isClosed) return true;
      emit(state.copyWith(status: VentasStatus.success, actionSuccessMessage: exito));
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(
        status: VentasStatus.failure,
        errorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => message.toString(),
          _ => e.toString(),
        },
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
