import 'package:equatable/equatable.dart';
import '../../../models/cliente.dart';
import '../../../models/venta.dart';

enum VentasStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Ventas gestionado por Cubit/BLoC.
class VentasState extends Equatable {
  final VentasStatus status;
  final List<Venta> ventas;
  final List<Venta> filteredVentas;
  final List<Cliente> clientes;
  final String? filtroClienteId;
  final String filterStatus;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const VentasState({
    this.status = VentasStatus.initial,
    this.ventas = const [],
    this.filteredVentas = const [],
    this.clientes = const [],
    this.filtroClienteId,
    this.filterStatus = 'Todos',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  VentasState copyWith({
    VentasStatus? status,
    List<Venta>? ventas,
    List<Venta>? filteredVentas,
    List<Cliente>? clientes,
    String? filtroClienteId,
    bool clearFiltroCliente = false,
    String? filterStatus,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return VentasState(
      status: status ?? this.status,
      ventas: ventas ?? this.ventas,
      filteredVentas: filteredVentas ?? this.filteredVentas,
      clientes: clientes ?? this.clientes,
      filtroClienteId:
          clearFiltroCliente ? null : (filtroClienteId ?? this.filtroClienteId),
      filterStatus: filterStatus ?? this.filterStatus,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == VentasStatus.loading || status == VentasStatus.initial) &&
      ventas.isEmpty;

  @override
  List<Object?> get props => [
        status,
        ventas,
        filteredVentas,
        clientes,
        filtroClienteId,
        filterStatus,
        errorMessage,
        actionSuccessMessage,
      ];
}
