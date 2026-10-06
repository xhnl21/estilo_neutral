import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/codigo_telefono.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'codigos_telefono_state.dart';

/// Cubit para gestión de estado del módulo de Códigos de Teléfono.
class CodigosTelefonoCubit extends Cubit<CodigosTelefonoState> {
  final SheetsDataService dataService;

  CodigosTelefonoCubit({required this.dataService}) : super(const CodigosTelefonoState()) {
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
    final currentList = List<CodigoTelefono>.from(dataService.codigosTelefono);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? CodigosTelefonoStatus.loading : CodigosTelefonoStatus.success,
      codigos: currentList,
      filteredCodigos: filtered,
      totalActivos: dataService.codigosTelefonoActivos.length,
      // El error de carga va aparte: reemitirlo como errorMessage mostraba
      // un aviso de error justo después del de éxito de una acción.
      errorCarga: dataService.errorMessage,
      limpiarErrorCarga: dataService.errorMessage == null,
      enUso: dataService.codigosTelefonoEnUso,
    ));
  }

  List<CodigoTelefono> _filter(List<CodigoTelefono> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      return c.codigo.toLowerCase().contains(q) || c.id.toLowerCase().contains(q);
    }).toList();
  }

  void search(String query) {
    final filtered = _filter(state.codigos, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredCodigos: filtered,
    ));
  }

  Future<void> refresh() async {
    Logger.info('CodigosTelefonoCubit: Refrescando códigos de teléfono desde Google Sheets...');
    emit(state.copyWith(status: CodigosTelefonoStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addCodigoTelefono(String codigo) async {
    emit(state.copyWith(status: CodigosTelefonoStatus.loading));
    try {
      await dataService.addCodigoTelefono(codigo: codigo);
      emit(state.copyWith(
        status: CodigosTelefonoStatus.success,
        actionSuccessMessage: 'Código de teléfono "$codigo" registrado con éxito.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CodigosTelefonoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    } finally {
      _syncFromService();
    }
  }

  Future<void> updateCodigoTelefono(String id, String nuevoCodigo) async {
    emit(state.copyWith(status: CodigosTelefonoStatus.loading));
    try {
      await dataService.updateCodigoTelefono(id: id, nuevoCodigo: nuevoCodigo);
      emit(state.copyWith(
        status: CodigosTelefonoStatus.success,
        actionSuccessMessage: 'Código actualizado a "$nuevoCodigo" con éxito.',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CodigosTelefonoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    } finally {
      _syncFromService();
    }
  }

  Future<bool> toggleCodigoTelefonoStatus(String id) async {
    try {
      final ok = await dataService.toggleCodigoTelefonoStatus(id);
      _syncFromService();
      return ok;
    } catch (e) {
      emit(state.copyWith(
        status: CodigosTelefonoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    }
  }

  Future<bool> deleteCodigoTelefono(String id) async {
    try {
      final ok = await dataService.deleteCodigoTelefono(id);
      emit(state.copyWith(
        status: CodigosTelefonoStatus.success,
        actionSuccessMessage: 'Código de teléfono eliminado con éxito.',
      ));
      _syncFromService();
      return ok;
    } catch (e) {
      emit(state.copyWith(
        status: CodigosTelefonoStatus.failure,
        errorMessage: _mensajeError(e),
      ));
      rethrow;
    }
  }

  bool isCodigoTelefonoEnUso(String codigo) => dataService.isCodigoTelefonoEnUso(codigo);

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
