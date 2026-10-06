import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/di/injection.dart';
import '../../../core/utils/logger.dart';
import '../../../features/credits/credits.dart';
import '../../../models/cliente.dart';
import '../../../models/documento_identidad.dart';
import '../../../models/telefono_ve.dart';
import '../../../models/venta.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'clientes_state.dart';

/// Cubit para gestión de estado del módulo de Clientes (arquitectura BLoC).
/// Elimina la necesidad de `setState()` y desacopla la UI de la lógica de negocio.
/// El alta/edición vive en `ClienteFormCubit`.
class ClientesCubit extends Cubit<ClientesState> {
  final SheetsDataService dataService;
  final SheetsCreditsDataSource creditsDataSource;

  ClientesCubit({
    required this.dataService,
    SheetsCreditsDataSource? creditsDataSource,
  })  : creditsDataSource =
            creditsDataSource ?? ServiceLocator().creditsDataSource,
        super(const ClientesState()) {
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
      status: dataService.isLoading
          ? ClientesStatus.loading
          : ClientesStatus.success,
      clientes: currentList,
      filteredClientes: filtered,
      resumenes: _buildResumenes(currentList),
      errorMessage: dataService.errorMessage,
      usuarioEmail: dataService.currentUsuarioEmail,
    ));
  }

  /// Calcula deuda real (a partir de las ventas) y saldo a favor (a partir
  /// del ledger de créditos, o del excedente de ventas si no hay ledger).
  Map<String, ClienteResumen> _buildResumenes(List<Cliente> clientes) {
    final ventasPorCliente = <String, List<Venta>>{};
    for (final v in dataService.ventas) {
      ventasPorCliente.putIfAbsent(v.clienteId, () => []).add(v);
    }
    final creditosPorCliente = <String, List<ClientCredit>>{};
    for (final c in creditsDataSource.credits) {
      creditosPorCliente.putIfAbsent(c.clienteId, () => []).add(c);
    }

    final resumenes = <String, ClienteResumen>{};
    for (final cliente in clientes) {
      final ventas = ventasPorCliente[cliente.id] ?? const <Venta>[];
      final creditos = creditosPorCliente[cliente.id] ?? const <ClientCredit>[];
      final disponibles = creditos.where((c) => c.isAvailable).toList();

      final deuda = ventas.fold<double>(
          0.0, (sum, v) => sum + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
      final saldoAFavor = creditos.isNotEmpty
          ? disponibles.fold<double>(0.0, (sum, c) => sum + c.saldoUsd)
          : ventas.fold<double>(0.0, (sum, v) => sum + v.excedenteUsd);

      resumenes[cliente.id] = ClienteResumen(
        deudaUsd: deuda,
        saldoAFavorUsd: saldoAFavor,
        ventasPendientes: ventas.where((v) => v.deudaUsd > 0).toList(),
        origenVentaIdCredito: disponibles.firstOrNull?.origenVentaId,
      );
    }
    return resumenes;
  }

  List<Cliente> _filter(List<Cliente> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    // "12.345.678" o "J-12345678-9" también encuentran la cédula guardada.
    final qDocumento =
        DocumentoIdentidad.normalizar(q).replaceAll(RegExp(r'^[VEJG]'), '');
    return list.where((c) {
      return c.nombre.toLowerCase().contains(q) ||
          c.telefono.toLowerCase().contains(q) ||
          (TelefonoVe.parse(c.telefono)?.local.contains(q) ?? false) ||
          c.id.toLowerCase().contains(q) ||
          c.documentoCompleto.toLowerCase().contains(q) ||
          (qDocumento.contains(RegExp(r'\d')) &&
              DocumentoIdentidad.normalizar(c.cedula).contains(qDocumento)) ||
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

  /// Alterna la apertura del panel acordeón de un cliente
  void toggleExpanded(String clienteId) {
    if (state.expandedClienteId == clienteId) {
      emit(state.copyWith(clearExpandedId: true));
    } else {
      emit(state.copyWith(expandedClienteId: clienteId));
    }
  }

  /// Refresca datos desde Google Sheets bajo demanda (Cero Polling)
  Future<void> refresh() async {
    Logger.info(
        'ClientesCubit: Refrescando lista de clientes desde Google Sheets...');
    emit(state.copyWith(status: ClientesStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Motivo por el que el cliente no se puede eliminar, o `null`.
  String? motivoNoEliminable(String id) =>
      dataService.motivoNoEliminableCliente(id);

  /// Desincorpora un cliente (si [motivoNoEliminable] lo permite). Si Sheets
  /// no lo confirma, el cliente vuelve a la lista y se informa el error.
  Future<void> deleteCliente(String id) async {
    Logger.warning('ClientesCubit: Eliminando cliente con ID: $id');
    try {
      await dataService.deleteCliente(id);
      if (isClosed) return;
      emit(state.copyWith(
        status: ClientesStatus.success,
        actionSuccessMessage: 'Cliente desincorporado con éxito.',
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => e.toString(),
      }));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
