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

  void addCuarentena(RegistroCuarentena item) {
    dataService.addCuarentena(item);
    emit(state.copyWith(
      status: CuarentenaStatus.success,
      actionSuccessMessage: 'Anomalía reportada a cuarentena.',
    ));
  }

  void updateCuarentena(RegistroCuarentena item) {
    dataService.updateCuarentena(item);
    emit(state.copyWith(
      status: CuarentenaStatus.success,
      actionSuccessMessage: 'Registro de cuarentena actualizado.',
    ));
  }

  void deleteCuarentena(String idOriginal) {
    dataService.deleteCuarentena(idOriginal);
    emit(state.copyWith(
      status: CuarentenaStatus.success,
      actionSuccessMessage: 'Registro removido de cuarentena.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
