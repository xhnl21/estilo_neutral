import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/compra_divisa.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import 'treasury_state.dart';

class TreasuryCubit extends Cubit<TreasuryState> {
  final SheetsDataService _dataService;

  TreasuryCubit({required SheetsDataService dataService})
      : _dataService = dataService,
        super(const TreasuryState()) {
    _dataService.addListener(_onDataChanged);
    _syncFromService();
  }

  void _onDataChanged() {
    if (!isClosed) {
      _syncFromService();
    }
  }

  void _syncFromService() {
    emit(state.copyWith(
      status: TreasuryStatus.success,
      comprasDivisas: List.unmodifiable(_dataService.comprasDivisas),
      isLoading: _dataService.isLoading,
    ));
  }

  String get nextCompraDivisaId => _dataService.nextCompraDivisaId;

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _dataService.fetchAllSheets();
      if (!isClosed) {
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Error al actualizar compras de divisas: $e',
        ));
      }
    }
  }

  /// Tasa BCV vigente, para precargar el formulario.
  double? get tasaBcvVigente => _dataService.tasaVigenteEnMonedaBase?.valor;

  /// Arma la compra desde el formulario. Devuelve el error de validación
  /// (antes: montos mal escritos se guardaban como 0 y las tasas como 474/480
  /// inventadas), o la compra lista para guardar.
  static ({CompraDivisa? compra, String? error}) construirCompra({
    required String id,
    required DateTime fechaCompra,
    required DateTime fechaEntrega,
    required String numeroOrden,
    required String capital,
    required String comision,
    required String plataforma,
    required String vendedor,
    required String tasaBcv,
    required String tasaUsd,
  }) {
    double? monto(String t) => double.tryParse(t.trim().replaceAll(',', '.'));
    final cap = monto(capital);
    final com = monto(comision.trim().isEmpty ? '0' : comision);
    final bcv = monto(tasaBcv);
    final usd = monto(tasaUsd);
    if (numeroOrden.trim().isEmpty) return (compra: null, error: 'El número de orden es obligatorio.');
    if (cap == null || cap <= 0) return (compra: null, error: 'Capital USD: debe ser un monto mayor a 0 (ej: 100.00).');
    if (com == null || com < 0) return (compra: null, error: 'Comisión: monto inválido.');
    if (com > cap) return (compra: null, error: 'La comisión no puede ser mayor que el capital.');
    if (bcv == null || bcv <= 0) return (compra: null, error: 'Tasa BCV: debe ser mayor a 0.');
    if (usd == null || usd <= 0) return (compra: null, error: 'Tasa USD: debe ser mayor a 0.');
    return (
      compra: CompraDivisa(
        id: id,
        fechaCompra: fechaCompra,
        fechaEntrega: fechaEntrega,
        capitalUsd: cap,
        comisionBinanceUsd: com,
        numeroOrden: numeroOrden.trim(),
        plataforma: plataforma.trim(),
        vendedor: vendedor.trim(),
        tasaBcv: bcv,
        tasaUsd: usd,
        validacion: 'OK',
      ),
      error: null,
    );
  }

  /// Número de orden repetido (otra compra de la organización con el mismo).
  bool ordenRepetida(String numeroOrden, {String? excluirId}) => state.comprasDivisas
      .any((c) => c.id != excluirId && c.numeroOrden.trim() == numeroOrden.trim());

  Future<bool> addCompra(CompraDivisa compra) => _ejecutar(
        () => _dataService.addCompraDivisa(compra),
        exito: 'Compra de divisas registrada correctamente',
      );

  Future<bool> updateCompra(CompraDivisa compra) => _ejecutar(
        () => _dataService.updateCompraDivisa(compra),
        exito: 'Compra de divisas actualizada correctamente',
      );

  Future<bool> deleteCompra(String id) => _ejecutar(
        () => _dataService.deleteCompraDivisa(id),
        exito: 'Compra eliminada correctamente',
      );

  Future<bool> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (!isClosed) emit(state.copyWith(actionSuccessMessage: exito));
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => message.toString(),
          _ => e.toString(),
        }));
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
  }
}
