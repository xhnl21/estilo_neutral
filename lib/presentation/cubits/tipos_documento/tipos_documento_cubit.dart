import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/tipo_documento.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'tipos_documento_state.dart';

/// Cubit para gestión de estado del módulo de Tipos de Documento.
class TiposDocumentoCubit extends Cubit<TiposDocumentoState> {
  final SheetsDataService dataService;

  TiposDocumentoCubit({required this.dataService}) : super(const TiposDocumentoState()) {
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
    final currentList = List<TipoDocumento>.from(dataService.tiposDocumento);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? TiposDocumentoStatus.loading : TiposDocumentoStatus.success,
      tipos: currentList,
      filteredTipos: filtered,
      totalActivos: dataService.tiposDocumentoActivos.length,
      // El error de carga va aparte: reemitirlo como errorMessage mostraba
      // un aviso de error justo después del de éxito de una acción.
      errorCarga: dataService.errorMessage,
      limpiarErrorCarga: dataService.errorMessage == null,
      enUso: dataService.tiposDocumentoEnUso,
    ));
  }

  List<TipoDocumento> _filter(List<TipoDocumento> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((t) {
      return t.tipo.toLowerCase().contains(q) ||
          t.descripcion.toLowerCase().contains(q) ||
          t.id.toLowerCase().contains(q);
    }).toList();
  }

  void search(String query) {
    final filtered = _filter(state.tipos, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredTipos: filtered,
    ));
  }

  Future<void> refresh() async {
    Logger.info('TiposDocumentoCubit: Refrescando tipos de documento desde Google Sheets...');
    emit(state.copyWith(status: TiposDocumentoStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addTipoDocumento({
    required String tipo,
    required String descripcion,
  }) async {
    emit(state.copyWith(status: TiposDocumentoStatus.loading));
    try {
      await dataService.addTipoDocumento(tipo: tipo, descripcion: descripcion);
      emit(state.copyWith(
        status: TiposDocumentoStatus.success,
        actionSuccessMessage: 'Tipo de documento "$tipo" registrado con éxito.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TiposDocumentoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    } finally {
      _syncFromService();
    }
  }

  Future<void> updateTipoDocumento({
    required String id,
    required String nuevoTipo,
    required String nuevaDescripcion,
  }) async {
    emit(state.copyWith(status: TiposDocumentoStatus.loading));
    try {
      await dataService.updateTipoDocumento(
        id: id,
        nuevoTipo: nuevoTipo,
        nuevaDescripcion: nuevaDescripcion,
      );
      emit(state.copyWith(
        status: TiposDocumentoStatus.success,
        actionSuccessMessage: 'Tipo de documento "$nuevoTipo" actualizado con éxito.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: TiposDocumentoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    } finally {
      _syncFromService();
    }
  }

  Future<bool> toggleTipoDocumentoStatus(String id) async {
    try {
      final ok = await dataService.toggleTipoDocumentoStatus(id);
      _syncFromService();
      return ok;
    } catch (e) {
      emit(state.copyWith(
        status: TiposDocumentoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    }
  }

  Future<bool> deleteTipoDocumento(String id) async {
    try {
      final ok = await dataService.deleteTipoDocumento(id);
      emit(state.copyWith(
        status: TiposDocumentoStatus.success,
        actionSuccessMessage: 'Tipo de documento eliminado con éxito.',
      ));
      _syncFromService();
      return ok;
    } catch (e) {
      emit(state.copyWith(
        status: TiposDocumentoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    }
  }

  bool isTipoDocumentoEnUso(String tipo) => dataService.isTipoDocumentoEnUso(tipo);

  /// Mensaje legible de los errores del servicio (sin "Bad state:" ni
  /// "Invalid argument(s):").
  static String _mensajeError(Object e) {
    if (e is StateError) return e.message;
    if (e is ArgumentError) return e.message.toString();
    return e.toString();
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
