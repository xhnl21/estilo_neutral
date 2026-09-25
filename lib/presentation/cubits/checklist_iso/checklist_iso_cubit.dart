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

  void addChecklistIso(ChecklistISO check) {
    dataService.addChecklistIso(check);
    emit(state.copyWith(
      status: ChecklistIsoStatus.success,
      actionSuccessMessage: 'Control normativo agregado con éxito.',
    ));
  }

  void updateChecklistIso(ChecklistISO check) {
    dataService.updateChecklistIso(check);
    emit(state.copyWith(
      status: ChecklistIsoStatus.success,
      actionSuccessMessage: 'Control normativo actualizado.',
    ));
  }

  void deleteChecklistIso(int nro) {
    dataService.deleteChecklistIso(nro);
    emit(state.copyWith(
      status: ChecklistIsoStatus.success,
      actionSuccessMessage: 'Control normativo revocado.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
