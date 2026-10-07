import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/usuario.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'usuarios_state.dart';

/// Cubit para gestión de estado reactivo del módulo de Usuarios.
class UsuariosCubit extends Cubit<UsuariosState> {
  final SheetsDataService dataService;

  UsuariosCubit({required this.dataService}) : super(const UsuariosState()) {
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
    final currentList = List<Usuario>.from(dataService.usuarios);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? UsuariosStatus.loading : UsuariosStatus.success,
      usuarios: currentList,
      filteredUsuarios: filtered,
      schemaMultiOrgListo: dataService.schemaMultiOrgListo,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<Usuario> _filter(List<Usuario> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) {
      return u.email.toLowerCase().contains(q) || u.nombre.toLowerCase().contains(q);
    }).toList();
  }

  void search(String query) {
    final filtered = _filter(state.usuarios, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredUsuarios: filtered,
    ));
  }

  void toggleExpanded(String usuarioId) {
    if (state.expandedUsuarioId == usuarioId) {
      emit(state.copyWith(clearExpandedId: true));
    } else {
      emit(state.copyWith(expandedUsuarioId: usuarioId));
    }
  }

  Future<void> refresh() async {
    Logger.info('UsuariosCubit: Refrescando usuarios desde Google Sheets...');
    emit(state.copyWith(status: UsuariosStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Quita el acceso a [usuario] (usuario y membresía). Si Sheets no lo
  /// confirma, el servicio revierte y se muestra el error.
  Future<void> deleteUsuario(Usuario usuario) async {
    emit(state.copyWith(status: UsuariosStatus.loading));
    try {
      final ok = await dataService.deleteUsuario(usuario);
      if (isClosed) return;
      emit(ok
          ? state.copyWith(
              status: UsuariosStatus.success,
              actionSuccessMessage: 'Se quitó el acceso a "${usuario.email}".',
            )
          : state.copyWith(
              status: UsuariosStatus.success,
              actionErrorMessage: 'No se pudo quitar el acceso a "${usuario.email}" en Google Sheets. No se cambió nada.',
            ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: UsuariosStatus.success,
        actionErrorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => message.toString(),
          _ => 'Error al quitar el acceso: $e',
        },
      ));
    }
  }

  /// Motivo por el que no se puede inactivar a [usuario], o `null`.
  String? motivoNoInactivable(Usuario usuario) => dataService.motivoNoInactivable(usuario);

  /// Activa o inactiva a [usuario] sin borrarlo. Inactivo no puede iniciar
  /// sesión y el servidor le cierra la sesión abierta (push silencioso).
  Future<void> cambiarEstado(Usuario usuario, {required bool activo}) async {
    emit(state.copyWith(status: UsuariosStatus.loading));
    try {
      await dataService.cambiarEstadoUsuario(usuario.id, activo: activo);
      if (isClosed) return;
      emit(state.copyWith(
        status: UsuariosStatus.success,
        actionSuccessMessage: activo
            ? '"${usuario.email}" puede volver a iniciar sesión.'
            : '"${usuario.email}" quedó inactivo: se cerró su sesión y no puede volver a entrar.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: UsuariosStatus.success,
        actionErrorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => message.toString(),
          _ => 'Error al cambiar el estado: $e',
        },
      ));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
