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

  SheetsDataService get dataService => _dataService;

  void _onDataChanged() {
    if (!isClosed) {
      _syncFromService();
    }
  }

  void _syncFromService() {
    final organizaciones = _dataService.organizaciones;
    emit(state.copyWith(
      status: OrganizacionesStatus.success,
      usuariosPorOrganizacion: {
        for (final o in organizaciones) o.id: _dataService.usuariosEnOrganizacion(o.id),
      },
      monedaPorOrganizacion: {
        for (final o in organizaciones) o.id: _dataService.monedaOrganizacion(o.id),
      },
      tasaManualPorOrganizacion: {
        for (final o in organizaciones)
          if (_dataService.tasaManualOrganizacion(o.id) case final t?) o.id: t,
      },
      organizaciones: List.unmodifiable(organizaciones),
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

  void toggleExpanded(String orgId) {
    if (state.expandedOrganizacionId == orgId) {
      emit(state.copyWith(clearExpandedId: true));
    } else {
      emit(state.copyWith(expandedOrganizacionId: orgId));
    }
  }

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
          errorMessage: _mensaje(e),
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
          errorMessage: _mensaje(e),
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
          errorMessage: _mensaje(e),
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
        emit(state.copyWith(errorMessage: _mensaje(e)));
      }
    }
  }

  Future<void> setTasaManualOrganizacion(String orgId, String moneda, double tasa) async {
    try {
      await _dataService.setTasaManualOrganizacion(orgId, moneda, tasa);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: _mensaje(e)));
      }
    }
  }

  Future<void> quitarTasaManualOrganizacion(String orgId) async {
    try {
      await _dataService.quitarTasaManualOrganizacion(orgId);
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: _mensaje(e)));
      }
    }
  }

  Future<bool> updateUsuario(Usuario usuario, {required String organizacionId}) async {
    try {
      final ok = await _dataService.updateUsuario(usuario, organizacionId: organizacionId);
      if (!isClosed) {
        if (!ok) emit(state.copyWith(errorMessage: 'No se pudo mover el usuario: Google Sheets no lo confirmó.'));
        _syncFromService();
      }
      return ok;
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Error al mover usuario: $e'));
      }
      return false;
    }
  }

  static String _mensaje(Object e) => switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => e.toString(),
      };

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
  }
}
