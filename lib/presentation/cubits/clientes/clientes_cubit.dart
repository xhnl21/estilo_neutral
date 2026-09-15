import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/cliente.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'clientes_state.dart';

/// Cubit para gestión de estado del módulo de Clientes (arquitectura BLoC).
/// Elimina la necesidad de `setState()` y desacopla la UI de la lógica de negocio.
class ClientesCubit extends Cubit<ClientesState> {
  final SheetsDataService dataService;

  ClientesCubit({required this.dataService}) : super(const ClientesState()) {
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
    final currentList = List<Cliente>.from(dataService.clientes);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? ClientesStatus.loading : ClientesStatus.success,
      clientes: currentList,
      filteredClientes: filtered,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<Cliente> _filter(List<Cliente> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          c.telefono.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();
  }

  /// Filtra clientes en tiempo real sin setState
  void search(String query) {
    if (query.trim().isNotEmpty) {
      Logger.debug('ClientesCubit: Filtrando clientes por término: "$query"');
    }
    final filtered = _filter(state.clientes, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredClientes: filtered,
    ));
  }

  /// Refresca datos desde Google Sheets bajo demanda (Cero Polling)
  Future<void> refresh() async {
    Logger.info('ClientesCubit: Refrescando lista de clientes desde Google Sheets...');
    emit(state.copyWith(status: ClientesStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Da de alta a un nuevo cliente y despacha sincronización remota
  Future<void> addCliente(Cliente cliente) async {
    Logger.info('ClientesCubit: Agregando cliente: ${cliente.id} (${cliente.nombre})');
    emit(state.copyWith(status: ClientesStatus.loading));
    final success = await dataService.addCliente(cliente);
    if (success) {
      emit(state.copyWith(
        status: ClientesStatus.success,
        actionSuccessMessage: 'Cliente "${cliente.nombre}" registrado y sincronizado en Google Sheets.',
      ));
    } else {
      emit(state.copyWith(
        status: ClientesStatus.success,
        actionSuccessMessage: 'Cliente "${cliente.nombre}" guardado localmente.',
      ));
    }
  }

  /// Actualiza datos de un cliente existente
  void updateCliente(Cliente cliente) {
    Logger.info('ClientesCubit: Actualizando cliente: ${cliente.id}');
    dataService.updateCliente(cliente);
    emit(state.copyWith(
      status: ClientesStatus.success,
      actionSuccessMessage: 'Cliente "${cliente.nombre}" actualizado con éxito.',
    ));
  }

  /// Desincorpora un cliente
  void deleteCliente(String id) {
    Logger.warning('ClientesCubit: Eliminando cliente con ID: $id');
    dataService.deleteCliente(id);
    emit(state.copyWith(
      status: ClientesStatus.success,
      actionSuccessMessage: 'Cliente desincorporado con éxito.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
