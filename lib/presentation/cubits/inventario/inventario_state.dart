import 'package:equatable/equatable.dart';
import '../../../models/producto.dart';

enum InventarioStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Inventario gobernado por Cubit/BLoC.
class InventarioState extends Equatable {
  final InventarioStatus status;
  final List<Producto> productos;
  final List<Producto> filteredProductos;
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const InventarioState({
    this.status = InventarioStatus.initial,
    this.productos = const [],
    this.filteredProductos = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  InventarioState copyWith({
    InventarioStatus? status,
    List<Producto>? productos,
    List<Producto>? filteredProductos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return InventarioState(
      status: status ?? this.status,
      productos: productos ?? this.productos,
      filteredProductos: filteredProductos ?? this.filteredProductos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == InventarioStatus.loading || status == InventarioStatus.initial) &&
      productos.isEmpty;

  @override
  List<Object?> get props => [
        status,
        productos,
        filteredProductos,
        searchQuery,
        errorMessage,
        actionSuccessMessage,
      ];
}
