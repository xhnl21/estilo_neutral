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

  Future<void> addReporteMigracion(ReporteMigracion rep) => _ejecutar(
        () => dataService.addReporteMigracion(rep),
        exito: 'Control de migración registrado.',
      );

  Future<void> updateReporteMigracion(ReporteMigracion rep) => _ejecutar(
        () => dataService.updateReporteMigracion(rep),
        exito: 'Control de migración actualizado.',
      );

  Future<void> deleteReporteMigracion(String id) => _ejecutar(
        () => dataService.deleteReporteMigracion(id),
        exito: 'Control de migración revocado.',
      );

  /// Espera la operación del servicio (que revierte si Sheets falla) y emite
  /// el mensaje de éxito o el error real.
  Future<void> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (isClosed) return;
      emit(state.copyWith(status: ReporteMigracionStatus.success, actionSuccessMessage: exito));
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
