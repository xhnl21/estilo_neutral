import 'package:equatable/equatable.dart';
import '../../../models/cliente.dart';

enum ClientesStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Clientes gestionado por Cubit/BLoC.
class ClientesState extends Equatable {
  final ClientesStatus status;
  final List<Cliente> clientes;
  final List<Cliente> filteredClientes;
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ClientesState({
    this.status = ClientesStatus.initial,
    this.clientes = const [],
    this.filteredClientes = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ClientesState copyWith({
    ClientesStatus? status,
    List<Cliente>? clientes,
    List<Cliente>? filteredClientes,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return ClientesState(
      status: status ?? this.status,
      clientes: clientes ?? this.clientes,
      filteredClientes: filteredClientes ?? this.filteredClientes,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        clientes,
        filteredClientes,
        searchQuery,
        errorMessage,
        actionSuccessMessage,
      ];
}
