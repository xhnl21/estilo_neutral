import 'package:equatable/equatable.dart';
import '../../../models/codigo_telefono.dart';

enum CodigosTelefonoStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Códigos de Teléfono (BLoC/Cubit).
class CodigosTelefonoState extends Equatable {
  final CodigosTelefonoStatus status;
  final List<CodigoTelefono> codigos;
  final List<CodigoTelefono> filteredCodigos;
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

  const CodigosTelefonoState({
    this.status = CodigosTelefonoStatus.initial,
    this.codigos = const [],
    this.filteredCodigos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
    this.errorCarga,
    this.enUso = const {},
  });

  CodigosTelefonoState copyWith({
    CodigosTelefonoStatus? status,
    List<CodigoTelefono>? codigos,
    List<CodigoTelefono>? filteredCodigos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
    String? errorCarga,
    bool limpiarErrorCarga = false,
    Set<String>? enUso,
  }) {
    return CodigosTelefonoState(
      status: status ?? this.status,
      codigos: codigos ?? this.codigos,
      filteredCodigos: filteredCodigos ?? this.filteredCodigos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      errorCarga: limpiarErrorCarga ? null : (errorCarga ?? this.errorCarga),
      enUso: enUso ?? this.enUso,
    );
  }

  bool get isInitialLoading =>
      (status == CodigosTelefonoStatus.loading || status == CodigosTelefonoStatus.initial) &&
      codigos.isEmpty;

  @override
  List<Object?> get props => [
        status,
        codigos,
        filteredCodigos,
        totalActivos,
        searchQuery,
        errorMessage,
        actionSuccessMessage,
        errorCarga,
        enUso,
      ];
}
