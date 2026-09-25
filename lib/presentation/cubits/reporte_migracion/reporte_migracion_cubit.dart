import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/reporte_migracion.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'reporte_migracion_state.dart';

/// Cubit para gestión de estado del Reporte de Migración.
class ReporteMigracionCubit extends Cubit<ReporteMigracionState> {
  final SheetsDataService dataService;

  ReporteMigracionCubit({required this.dataService}) : super(const ReporteMigracionState()) {
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
    final currentList = List<ReporteMigracion>.from(dataService.reportesMigracion);
    emit(state.copyWith(
      status: dataService.isLoading ? ReporteMigracionStatus.loading : ReporteMigracionStatus.success,
      reportes: currentList,
      errorMessage: dataService.errorMessage,
    ));
  }

  Future<void> refresh() async {
    Logger.info('ReporteMigracionCubit: Refrescando reporte de migración desde Google Sheets...');
    emit(state.copyWith(status: ReporteMigracionStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  void addReporteMigracion(ReporteMigracion rep) {
    dataService.addReporteMigracion(rep);
    emit(state.copyWith(
      status: ReporteMigracionStatus.success,
      actionSuccessMessage: 'Control de migración registrado.',
    ));
  }

  void updateReporteMigracion(int index, ReporteMigracion rep) {
    dataService.updateReporteMigracion(index, rep);
    emit(state.copyWith(
      status: ReporteMigracionStatus.success,
      actionSuccessMessage: 'Control de migración actualizado.',
    ));
  }

  void deleteReporteMigracion(int index) {
    dataService.deleteReporteMigracion(index);
    emit(state.copyWith(
      status: ReporteMigracionStatus.success,
      actionSuccessMessage: 'Control de migración revocado.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
