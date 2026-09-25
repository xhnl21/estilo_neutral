import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/resumen_diario.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import 'reporting_state.dart';

class ReportingCubit extends Cubit<ReportingState> {
  final SheetsDataService _dataService;

  ReportingCubit({required SheetsDataService dataService})
      : _dataService = dataService,
        super(const ReportingState()) {
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
      status: ReportingStatus.success,
      resumenesDiarios: List.unmodifiable(_dataService.resumenesDiarios),
      isLoading: _dataService.isLoading,
    ));
  }

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
          errorMessage: 'Error al actualizar cierres diarios: $e',
        ));
      }
    }
  }

  void addResumen(ResumenDiario resumen) {
    try {
      _dataService.addResumenDiario(resumen);
      if (!isClosed) {
        emit(state.copyWith(
          actionSuccessMessage: 'Cierre diario registrado correctamente',
        ));
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          errorMessage: 'Error al registrar cierre: $e',
        ));
      }
    }
  }

  void updateResumen(ResumenDiario resumen) {
    try {
      _dataService.updateResumenDiario(resumen);
      if (!isClosed) {
        emit(state.copyWith(
          actionSuccessMessage: 'Cierre diario actualizado correctamente',
        ));
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          errorMessage: 'Error al actualizar cierre: $e',
        ));
      }
    }
  }

  void deleteResumen(DateTime fecha) {
    try {
      _dataService.deleteResumenDiario(fecha);
      if (!isClosed) {
        emit(state.copyWith(
          actionSuccessMessage: 'Cierre diario eliminado correctamente',
        ));
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          errorMessage: 'Error al eliminar cierre: $e',
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
