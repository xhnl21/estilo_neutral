import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'factura_detalle_state.dart';

/// Cubit para gestión de estado del detalle de una factura.
class FacturaDetalleCubit extends Cubit<FacturaDetalleState> {
  final SheetsDataService dataService;

  FacturaDetalleCubit({
    required this.dataService,
    required String ventaId,
  }) : super(FacturaDetalleState(ventaId: ventaId)) {
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
    final venta = dataService.ventas.where((v) => v.id == state.ventaId).firstOrNull;
    final cliente = venta != null
        ? dataService.clientes.where((c) => c.id == venta.clienteId).firstOrNull
        : null;
    final items = venta != null ? dataService.itemsDeVenta(venta.id) : const [];
    final abonos = venta != null
        ? (dataService.abonosDeVenta(venta.id).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha)))
        : const [];

    emit(state.copyWith(
      status: dataService.isLoading ? FacturaDetalleStatus.loading : FacturaDetalleStatus.success,
      venta: venta,
      clearVenta: venta == null,
      cliente: cliente,
      clearCliente: cliente == null,
      items: List.from(items),
      abonos: List.from(abonos),
      errorMessage: dataService.errorMessage,
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
