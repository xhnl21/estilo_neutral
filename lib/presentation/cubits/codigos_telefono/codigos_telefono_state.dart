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
  final String? errorMessage;
  final String? actionSuccessMessage;

  const CodigosTelefonoState({
    this.status = CodigosTelefonoStatus.initial,
    this.codigos = const [],
    this.filteredCodigos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  CodigosTelefonoState copyWith({
    CodigosTelefonoStatus? status,
    List<CodigoTelefono>? codigos,
    List<CodigoTelefono>? filteredCodigos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return CodigosTelefonoState(
      status: status ?? this.status,
      codigos: codigos ?? this.codigos,
      filteredCodigos: filteredCodigos ?? this.filteredCodigos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
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
      ];
}
