import 'package:equatable/equatable.dart';
import '../../../models/tipo_documento.dart';

enum TiposDocumentoStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Tipos de Documento (BLoC/Cubit).
class TiposDocumentoState extends Equatable {
  final TiposDocumentoStatus status;
  final List<TipoDocumento> tipos;
  final List<TipoDocumento> filteredTipos;
  final int totalActivos;
  final String searchQuery;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const TiposDocumentoState({
    this.status = TiposDocumentoStatus.initial,
    this.tipos = const [],
    this.filteredTipos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  TiposDocumentoState copyWith({
    TiposDocumentoStatus? status,
    List<TipoDocumento>? tipos,
    List<TipoDocumento>? filteredTipos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return TiposDocumentoState(
      status: status ?? this.status,
      tipos: tipos ?? this.tipos,
      filteredTipos: filteredTipos ?? this.filteredTipos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == TiposDocumentoStatus.loading || status == TiposDocumentoStatus.initial) &&
      tipos.isEmpty;

  @override
  List<Object?> get props => [
        status,
        tipos,
        filteredTipos,
        totalActivos,
        searchQuery,
        errorMessage,
        actionSuccessMessage,
      ];
}
