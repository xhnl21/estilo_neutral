import 'package:equatable/equatable.dart';

import '../../../models/cuenta_bancaria.dart';

enum DatosBancariosStatus { initial, loading, success, failure }

/// Estado del listado de datos bancarios de la organización.
class DatosBancariosState extends Equatable {
  final DatosBancariosStatus status;
  final List<CuentaBancaria> cuentas;

  /// Catálogo completo, por ID (también bancos inactivos de cuentas viejas).
  final Map<String, Banco> bancos;

  /// `null` = todos los tipos.
  final TipoCuentaBancaria? filtroTipo;

  final String? actionSuccessMessage;
  final String? errorMessage;

  const DatosBancariosState({
    this.status = DatosBancariosStatus.initial,
    this.cuentas = const [],
    this.bancos = const {},
    this.filtroTipo,
    this.actionSuccessMessage,
    this.errorMessage,
  });

  List<CuentaBancaria> get filtradas => filtroTipo == null ? cuentas : cuentas.where((c) => c.tipo == filtroTipo).toList();

  int cantidad(TipoCuentaBancaria tipo) => cuentas.where((c) => c.tipo == tipo).length;

  DatosBancariosState copyWith({
    DatosBancariosStatus? status,
    List<CuentaBancaria>? cuentas,
    Map<String, Banco>? bancos,
    TipoCuentaBancaria? filtroTipo,
    bool limpiarFiltro = false,
    String? actionSuccessMessage,
    String? errorMessage,
  }) {
    return DatosBancariosState(
      status: status ?? this.status,
      cuentas: cuentas ?? this.cuentas,
      bancos: bancos ?? this.bancos,
      filtroTipo: limpiarFiltro ? null : (filtroTipo ?? this.filtroTipo),
      // Transitorios: solo viven en la emisión que los trae.
      actionSuccessMessage: actionSuccessMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, cuentas, bancos, filtroTipo, actionSuccessMessage, errorMessage];
}
