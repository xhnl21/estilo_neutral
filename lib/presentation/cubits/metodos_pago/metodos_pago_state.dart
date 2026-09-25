import 'package:equatable/equatable.dart';
import '../../../models/metodo_pago.dart';

enum MetodosPagoStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Métodos de Pago (BLoC/Cubit).
class MetodosPagoState extends Equatable {
  final MetodosPagoStatus status;
  final List<MetodoPago> metodos;
  final List<MetodoPago> filteredMetodos;
  final int totalActivos;
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const MetodosPagoState({
    this.status = MetodosPagoStatus.initial,
    this.metodos = const [],
    this.filteredMetodos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  MetodosPagoState copyWith({
    MetodosPagoStatus? status,
    List<MetodoPago>? metodos,
    List<MetodoPago>? filteredMetodos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return MetodosPagoState(
      status: status ?? this.status,
      metodos: metodos ?? this.metodos,
      filteredMetodos: filteredMetodos ?? this.filteredMetodos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == MetodosPagoStatus.loading || status == MetodosPagoStatus.initial) &&
      metodos.isEmpty;

  @override
  List<Object?> get props => [
        status,
        metodos,
        filteredMetodos,
        totalActivos,
        searchQuery,
        errorMessage,
        actionSuccessMessage,
      ];
}
