import 'package:equatable/equatable.dart';
import '../../../models/cliente.dart';
import '../../../models/venta.dart';

enum ClientesStatus { initial, loading, success, failure }

/// Totales financieros de un cliente, derivados de sus ventas y créditos.
/// Se calculan en [ClientesCubit] para que la vista no contenga lógica de negocio.
class ClienteResumen extends Equatable {
  final double deudaUsd;
  final double saldoAFavorUsd;

  /// Ventas del cliente con deuda pendiente (destino al aplicar crédito).
  final List<Venta> ventasPendientes;

  /// Venta de origen del primer crédito disponible, si lo hay.
  final String? origenVentaIdCredito;

  const ClienteResumen({
    this.deudaUsd = 0.0,
    this.saldoAFavorUsd = 0.0,
    this.ventasPendientes = const [],
    this.origenVentaIdCredito,
  });

  bool get hasDebt => deudaUsd > 0;

  @override
  List<Object?> get props =>
      [deudaUsd, saldoAFavorUsd, ventasPendientes, origenVentaIdCredito];
}

/// Estado inmutable para el módulo de Clientes gestionado por Cubit/BLoC.
class ClientesState extends Equatable {
  final ClientesStatus status;
  final List<Cliente> clientes;
  final List<Cliente> filteredClientes;
  final Map<String, ClienteResumen> resumenes;
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;
  final String? usuarioEmail;

  final String? expandedClienteId;

  const ClientesState({
    this.status = ClientesStatus.initial,
    this.clientes = const [],
    this.filteredClientes = const [],
    this.resumenes = const {},
    this.searchQuery = '',
    this.expandedClienteId,
    this.errorMessage,
    this.actionSuccessMessage,
    this.usuarioEmail,
  });

  ClienteResumen resumenDe(String clienteId) =>
      resumenes[clienteId] ?? const ClienteResumen();

  ClientesState copyWith({
    ClientesStatus? status,
    List<Cliente>? clientes,
    List<Cliente>? filteredClientes,
    Map<String, ClienteResumen>? resumenes,
    String? searchQuery,
    String? expandedClienteId,
    bool clearExpandedId = false,
    String? errorMessage,
    String? actionSuccessMessage,
    String? usuarioEmail,
  }) {
    return ClientesState(
      status: status ?? this.status,
      clientes: clientes ?? this.clientes,
      filteredClientes: filteredClientes ?? this.filteredClientes,
      resumenes: resumenes ?? this.resumenes,
      searchQuery: searchQuery ?? this.searchQuery,
      expandedClienteId: clearExpandedId
          ? null
          : (expandedClienteId ?? this.expandedClienteId),
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      usuarioEmail: usuarioEmail ?? this.usuarioEmail,
    );
  }

  bool get isInitialLoading =>
      (status == ClientesStatus.loading || status == ClientesStatus.initial) &&
      clientes.isEmpty;

  @override
  List<Object?> get props => [
        status,
        clientes,
        filteredClientes,
        resumenes,
        searchQuery,
        expandedClienteId,
        errorMessage,
        actionSuccessMessage,
        usuarioEmail,
      ];
}
