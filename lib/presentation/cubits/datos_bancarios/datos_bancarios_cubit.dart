import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../models/cuenta_bancaria.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'datos_bancarios_state.dart';

/// Listado de datos bancarios (transferencia y pago móvil) de la
/// organización actual: filtro por tipo, activar/inactivar y eliminar. El
/// alta y la edición viven en [CuentaBancariaFormCubit].
class DatosBancariosCubit extends Cubit<DatosBancariosState> {
  final SheetsDataService dataService;

  DatosBancariosCubit({required this.dataService}) : super(const DatosBancariosState()) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final bancos = {for (final b in dataService.bancos) b.id: b};
    String nombre(CuentaBancaria c) => bancos[c.bancoId]?.nombre ?? '';
    // Activas primero; después por banco y titular.
    final cuentas = List.of(dataService.cuentasBancarias)
      ..sort((a, b) {
        if (a.activa != b.activa) return a.activa ? -1 : 1;
        final porBanco = nombre(a).toLowerCase().compareTo(nombre(b).toLowerCase());
        return porBanco != 0 ? porBanco : a.titular.toLowerCase().compareTo(b.titular.toLowerCase());
      });
    emit(state.copyWith(
      status: dataService.isLoading ? DatosBancariosStatus.loading : DatosBancariosStatus.success,
      cuentas: cuentas,
      bancos: bancos,
    ));
  }

  void filtrarPorTipo(TipoCuentaBancaria? tipo) {
    emit(tipo == null ? state.copyWith(limpiarFiltro: true) : state.copyWith(filtroTipo: tipo));
  }

  Future<void> refresh() async {
    emit(state.copyWith(status: DatosBancariosStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> cambiarEstado(CuentaBancaria cuenta, {required bool activa}) async {
    await _accion(
      () => dataService.updateCuentaBancaria(cuenta.copyWith(activa: activa)),
      activa ? 'Dato bancario activado.' : 'Dato bancario inactivado.',
    );
  }

  Future<void> eliminar(CuentaBancaria cuenta) async {
    await _accion(() => dataService.deleteCuentaBancaria(cuenta.id), 'Dato bancario eliminado.');
  }

  Future<void> _accion(Future<void> Function() hacer, String exito) async {
    try {
      await hacer();
      if (!isClosed) emit(state.copyWith(actionSuccessMessage: exito));
    } catch (e, st) {
      Logger.error('DatosBancariosCubit: la acción falló', e, st);
      if (isClosed) return;
      emit(state.copyWith(errorMessage: switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => '$message',
        _ => 'No se pudo completar: $e',
      }));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
