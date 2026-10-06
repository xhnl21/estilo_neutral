import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/registro_cuarentena.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'cuarentena_state.dart';

/// Cubit para gestión de estado de la Bandeja de Cuarentena.
class CuarentenaCubit extends Cubit<CuarentenaState> {
  final SheetsDataService dataService;

  CuarentenaCubit({required this.dataService}) : super(const CuarentenaState()) {
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
    final currentList = List<RegistroCuarentena>.from(dataService.cuarentenas);
    emit(state.copyWith(
      status: dataService.isLoading ? CuarentenaStatus.loading : CuarentenaStatus.success,
      items: currentList,
      errorMessage: dataService.errorMessage,
    ));
  }

  Future<void> refresh() async {
    Logger.info('CuarentenaCubit: Refrescando cuarentena desde Google Sheets...');
    emit(state.copyWith(status: CuarentenaStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addCuarentena(RegistroCuarentena item) => _ejecutar(
        () => dataService.addCuarentena(item),
        exito: 'Anomalía reportada a cuarentena.',
      );

  Future<void> updateCuarentena(RegistroCuarentena item) => _ejecutar(
        () => dataService.updateCuarentena(item),
        exito: 'Registro de cuarentena actualizado.',
      );

  Future<void> deleteCuarentena(String id) => _ejecutar(
        () => dataService.deleteCuarentena(id),
        exito: 'Registro removido de cuarentena.',
      );

  /// Espera la operación del servicio (que revierte si Sheets falla) y emite
  /// el mensaje de éxito o el error real.
  Future<void> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (isClosed) return;
      emit(state.copyWith(status: CuarentenaStatus.success, actionSuccessMessage: exito));
    } catch (e) {
      if (isClosed) return;
      final mensaje = switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => e.toString(),
      };
      emit(state.copyWith(errorMessage: mensaje));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
