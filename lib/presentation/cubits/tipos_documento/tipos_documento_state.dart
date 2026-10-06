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
  /// Error de una acción (transitorio: se muestra una vez).
  final String? errorMessage;
  final String? actionSuccessMessage;

  /// Error de la última carga de Sheets; se muestra fijo en la pantalla,
  /// no como aviso de una acción.
  final String? errorCarga;

  /// Claves en uso (por clientes, usuarios, ventas o abonos), calculadas una
  /// vez por sincronización y no por cada fila de la lista.
  final Set<String> enUso;

  const TiposDocumentoState({
    this.status = TiposDocumentoStatus.initial,
    this.tipos = const [],
    this.filteredTipos = const [],
    this.totalActivos = 0,
    this.searchQuery = '',
    this.errorMessage,
    this.actionSuccessMessage,
    this.errorCarga,
    this.enUso = const {},
  });

  TiposDocumentoState copyWith({
    TiposDocumentoStatus? status,
    List<TipoDocumento>? tipos,
    List<TipoDocumento>? filteredTipos,
    int? totalActivos,
    String? searchQuery,
    String? errorMessage,
    String? actionSuccessMessage,
    String? errorCarga,
    bool limpiarErrorCarga = false,
    Set<String>? enUso,
  }) {
    return TiposDocumentoState(
      status: status ?? this.status,
      tipos: tipos ?? this.tipos,
      filteredTipos: filteredTipos ?? this.filteredTipos,
      totalActivos: totalActivos ?? this.totalActivos,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
      errorCarga: limpiarErrorCarga ? null : (errorCarga ?? this.errorCarga),
      enUso: enUso ?? this.enUso,
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
        errorCarga,
        enUso,
      ];
}
