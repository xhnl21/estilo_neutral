import 'package:equatable/equatable.dart';
import '../../../models/tasa_registro.dart';

enum TasasStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Tasas (BLoC/Cubit).
class TasasState extends Equatable {
  final TasasStatus status;
  final List<TasaRegistro> tasas;
  final TasaRegistro? usdVigente;
  final TasaRegistro? eurVigente;
  final String? monedaActual;
  final bool isActualizandoTasaHoy;
  final String? actionMessage;
  final bool actionSuccess;
  final String? errorMessage;

  const TasasState({
    this.status = TasasStatus.initial,
    this.tasas = const [],
    this.usdVigente,
    this.eurVigente,
    this.monedaActual,
    this.isActualizandoTasaHoy = false,
    this.actionMessage,
    this.actionSuccess = true,
    this.errorMessage,
  });

  TasasState copyWith({
    TasasStatus? status,
    List<TasaRegistro>? tasas,
    TasaRegistro? usdVigente,
    TasaRegistro? eurVigente,
    String? monedaActual,
    bool? isActualizandoTasaHoy,
    String? actionMessage,
    bool? actionSuccess,
    String? errorMessage,
  }) {
    return TasasState(
      status: status ?? this.status,
      tasas: tasas ?? this.tasas,
      usdVigente: usdVigente ?? this.usdVigente,
      eurVigente: eurVigente ?? this.eurVigente,
      monedaActual: monedaActual ?? this.monedaActual,
      isActualizandoTasaHoy: isActualizandoTasaHoy ?? this.isActualizandoTasaHoy,
      actionMessage: actionMessage,
      actionSuccess: actionSuccess ?? this.actionSuccess,
      errorMessage: errorMessage,
    );
  }

  bool get isInitialLoading =>
      (status == TasasStatus.loading || status == TasasStatus.initial) && tasas.isEmpty;

  @override
  List<Object?> get props => [
        status,
        tasas,
        usdVigente,
        eurVigente,
        monedaActual,
        isActualizandoTasaHoy,
        actionMessage,
        actionSuccess,
        errorMessage,
      ];
}
