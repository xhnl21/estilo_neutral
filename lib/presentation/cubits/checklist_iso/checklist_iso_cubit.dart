import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/checklist_iso.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'checklist_iso_state.dart';

/// Cubit para gestión de estado de Matriz de Cumplimiento ISO.
class ChecklistIsoCubit extends Cubit<ChecklistIsoState> {
  final SheetsDataService dataService;

  ChecklistIsoCubit({required this.dataService}) : super(const ChecklistIsoState()) {
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
    final currentList = List<ChecklistISO>.from(dataService.checklistIsos);
    final totalConformes = currentList.where((i) => i.estado == '☑').length;
    final porcentaje = currentList.isNotEmpty
        ? (totalConformes / currentList.length * 100).round()
        : 0;

    emit(state.copyWith(
      status: dataService.isLoading ? ChecklistIsoStatus.loading : ChecklistIsoStatus.success,
      items: currentList,
      totalConformes: totalConformes,
      porcentaje: porcentaje,
      errorMessage: dataService.errorMessage,
    ));
  }

  Future<void> refresh() async {
    Logger.info('ChecklistIsoCubit: Refrescando matriz de cumplimiento ISO...');
    emit(state.copyWith(status: ChecklistIsoStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Nro provisional para un control nuevo (el servidor asigna el definitivo).
  int get nextNro => dataService.nextChecklistNro;

  Future<void> addChecklistIso(ChecklistISO check) => _ejecutar(
        () => dataService.addChecklistIso(check),
        exito: 'Control normativo agregado con éxito.',
      );

  Future<void> updateChecklistIso(ChecklistISO check) => _ejecutar(
        () => dataService.updateChecklistIso(check),
        exito: 'Control normativo actualizado.',
      );

  Future<void> toggleChecklistEstado(String id) => _ejecutar(
        () => dataService.toggleChecklistEstado(id),
        exito: 'Estado del control actualizado.',
      );

  Future<void> deleteChecklistIso(String id) => _ejecutar(
        () => dataService.deleteChecklistIso(id),
        exito: 'Control normativo revocado.',
      );

  /// Espera la operación del servicio (que revierte si Sheets falla) y emite
  /// el mensaje de éxito o el error real.
  Future<void> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (isClosed) return;
      emit(state.copyWith(status: ChecklistIsoStatus.success, actionSuccessMessage: exito));
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
