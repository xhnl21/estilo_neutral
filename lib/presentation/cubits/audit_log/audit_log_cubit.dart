import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/audit_log.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'audit_log_state.dart';

/// Cubit para gestión de estado de Bitácora de Auditoría.
class AuditLogCubit extends Cubit<AuditLogState> {
  final SheetsDataService dataService;

  AuditLogCubit({required this.dataService}) : super(const AuditLogState()) {
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
    final currentList = List<AuditLog>.from(dataService.auditLogs);
    final filtered = _filter(currentList, state.selectedHoja);
    emit(state.copyWith(
      status: dataService.isLoading ? AuditLogStatus.loading : AuditLogStatus.success,
      logs: currentList,
      filteredLogs: filtered,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<AuditLog> _filter(List<AuditLog> list, String hoja) {
    if (hoja == 'Todas') return list;
    return list.where((l) => l.hoja.toLowerCase() == hoja.toLowerCase()).toList();
  }

  void selectHoja(String hoja) {
    final filtered = _filter(state.logs, hoja);
    emit(state.copyWith(
      selectedHoja: hoja,
      filteredLogs: filtered,
    ));
  }

  Future<void> refresh() async {
    Logger.info('AuditLogCubit: Refrescando bitácora de auditoría desde Google Sheets...');
    emit(state.copyWith(status: AuditLogStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  void addAuditLogManual(AuditLog log) {
    dataService.addAuditLogManual(log);
    emit(state.copyWith(
      status: AuditLogStatus.success,
      actionSuccessMessage: 'Checkpoint de auditoría registrado.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
