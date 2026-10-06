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
  /// Error de una acción (transitorio: se muestra una vez).
  final String? errorMessage;
  final String? actionSuccessMessage;

  /// Error de la última carga de Sheets; se muestra fijo en la pantalla,
  /// no como aviso de una acción.
  final String? errorCarga;

  /// Claves en uso (por clientes, usuarios, ventas o abonos), calculadas una
  /// vez por sincronización y no por cada fila de la lista.
  final Set<String> enUso;

  const MetodosPagoState({
    this.status = MetodosPagoStatus.initial,
    this.metodos = const [],
    this.filteredMetodos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
    this.errorCarga,
    this.enUso = const {},
  });

  MetodosPagoState copyWith({
    MetodosPagoStatus? status,
    List<MetodoPago>? metodos,
    List<MetodoPago>? filteredMetodos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
    String? errorCarga,
    bool limpiarErrorCarga = false,
    Set<String>? enUso,
  }) {
    return MetodosPagoState(
      status: status ?? this.status,
      metodos: metodos ?? this.metodos,
      filteredMetodos: filteredMetodos ?? this.filteredMetodos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      errorCarga: limpiarErrorCarga ? null : (errorCarga ?? this.errorCarga),
      enUso: enUso ?? this.enUso,
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
        errorCarga,
        enUso,
      ];
}
