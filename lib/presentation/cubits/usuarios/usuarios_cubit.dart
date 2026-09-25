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

  Future<void> refresh() async {
    Logger.info('UsuariosCubit: Refrescando usuarios desde Google Sheets...');
    emit(state.copyWith(status: UsuariosStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addUsuario(Usuario usuario, {required String organizacionId}) async {
    emit(state.copyWith(status: UsuariosStatus.loading));
    final success = await dataService.addUsuario(usuario, organizacionId: organizacionId);
    emit(state.copyWith(
      status: UsuariosStatus.success,
      actionSuccessMessage: success
          ? 'Usuario "${usuario.email}" registrado y sincronizado en Google Sheets.'
          : 'Usuario "${usuario.email}" guardado localmente.',
    ));
  }

  Future<void> updateUsuario(Usuario usuario, {required String organizacionId}) async {
    emit(state.copyWith(status: UsuariosStatus.loading));
    final success = await dataService.updateUsuario(usuario, organizacionId: organizacionId);
    emit(state.copyWith(
      status: UsuariosStatus.success,
      actionSuccessMessage: success
          ? 'Usuario "${usuario.email}" actualizado con éxito.'
          : 'Usuario "${usuario.email}" actualizado localmente.',
    ));
  }

  Future<void> deleteUsuario(Usuario usuario) async {
    emit(state.copyWith(status: UsuariosStatus.loading));
    final success = await dataService.deleteUsuario(usuario);
    emit(state.copyWith(
      status: UsuariosStatus.success,
      actionSuccessMessage: success
          ? 'Usuario "${usuario.email}" desincorporado con éxito.'
          : 'Usuario "${usuario.email}" desincorporado localmente.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
