import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/models.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'organizaciones_state.dart';

class OrganizacionesCubit extends Cubit<OrganizacionesState> {
  final SheetsDataService _dataService;

  OrganizacionesCubit({required SheetsDataService dataService})
      : _dataService = dataService,
        super(const OrganizacionesState()) {
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
      status: OrganizacionesStatus.success,
      organizaciones: List.unmodifiable(_dataService.organizaciones),
      usuarios: List.unmodifiable(_dataService.usuarios),
      schemaMultiOrgListo: _dataService.schemaMultiOrgListo,
      isRefreshing: _dataService.isLoading,
    ));
  }

  int usuariosEnOrganizacion(String orgId) =>
      _dataService.usuariosEnOrganizacion(orgId);

  String? organizacionIdForUsuario(String email) =>
      _dataService.organizacionIdForUsuario(email);

  TasaRegistro? tasaManualOrganizacion(String orgId) =>
      _dataService.tasaManualOrganizacion(orgId);

  String monedaOrganizacion(String orgId) =>
      _dataService.monedaOrganizacion(orgId);

  Future<void> refresh() async {
    emit(state.copyWith(isRefreshing: true));
    try {
      await _dataService.fetchAllSheets();
      if (!isClosed) {
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          isRefreshing: false,
          errorMessage: 'Error al actualizar organizaciones: $e',
        ));
      }
    }
  }

  Future<bool> addOrganizacion(String nombre) async {
    emit(state.copyWith(status: OrganizacionesStatus.loading));
    try {
      await _dataService.addOrganizacion(nombre);
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.success,
          actionSuccessMessage: 'Organización creada exitosamente',
        ));
        _syncFromService();
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.failure,
          errorMessage: 'Error al crear organización: $e',
        ));
      }
      return false;
    }
  }

  Future<bool> updateOrganizacion(Organizacion org) async {
    emit(state.copyWith(status: OrganizacionesStatus.loading));
    try {
      await _dataService.updateOrganizacion(org);
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.success,
          actionSuccessMessage: 'Organización actualizada exitosamente',
        ));
        _syncFromService();
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.failure,
          errorMessage: 'Error al actualizar organización: $e',
        ));
      }
      return false;
    }
  }

  Future<bool> deleteOrganizacion(String id) async {
    emit(state.copyWith(status: OrganizacionesStatus.loading));
    try {
      await _dataService.deleteOrganizacion(id);
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.success,
          actionSuccessMessage: 'Organización eliminada exitosamente',
        ));
        _syncFromService();
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          status: OrganizacionesStatus.failure,
          errorMessage: 'Error al eliminar organización: $e',
        ));
      }
      return false;
    }
  }

  Future<void> setMonedaOrganizacion(String orgId, String moneda) async {
    try {
      await _dataService.setMonedaOrganizacion(orgId, moneda);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Error al actualizar moneda: $e'));
      }
    }
  }

  Future<void> setTasaManualOrganizacion(String orgId, String moneda, double tasa) async {
    try {
      await _dataService.setTasaManualOrganizacion(orgId, moneda, tasa);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Error al actualizar tasa manual: $e'));
      }
    }
  }

  Future<void> quitarTasaManualOrganizacion(String orgId) async {
    try {
      await _dataService.quitarTasaManualOrganizacion(orgId);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Error al quitar tasa manual: $e'));
      }
    }
  }

  Future<bool> updateUsuario(Usuario usuario, {required String organizacionId}) async {
    try {
      await _dataService.updateUsuario(usuario, organizacionId: organizacionId);
      if (!isClosed) {
        _syncFromService();
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Error al mover usuario: $e'));
      }
      return false;
    }
  }

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
  }
}
