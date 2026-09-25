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

  Future<bool> addCompra(CompraDivisa compra) async {
    try {
      final success = await _dataService.addCompraDivisa(compra);
      if (!isClosed) {
        if (success) {
          emit(state.copyWith(
            actionSuccessMessage: 'Compra de divisas registrada correctamente',
          ));
        }
        _syncFromService();
      }
      return success;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: TreasuryStatus.failure,
          errorMessage: 'Error al registrar compra: $e',
        ));
      }
      return false;
    }
  }

  void updateCompra(CompraDivisa compra) {
    try {
      _dataService.updateCompraDivisa(compra);
      if (!isClosed) {
        emit(state.copyWith(
          actionSuccessMessage: 'Compra de divisas actualizada correctamente',
        ));
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          errorMessage: 'Error al actualizar compra: $e',
        ));
      }
    }
  }

  void deleteCompra(String id) {
    try {
      _dataService.deleteCompraDivisa(id);
      if (!isClosed) {
        emit(state.copyWith(
          actionSuccessMessage: 'Compra eliminada correctamente',
        ));
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          errorMessage: 'Error al eliminar compra: $e',
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
  }
}
