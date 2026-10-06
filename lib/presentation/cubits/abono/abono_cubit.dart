import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'abono_state.dart';

/// Cubit del diálogo "Abono a Venta": deuda actual, métodos de pago y tasas
/// sincronizados con [SheetsDataService], selección, validación del monto y
/// registro del abono (ver [SheetsDataService.registrarAbono]).
class AbonoCubit extends Cubit<AbonoState> {
  final SheetsDataService dataService;
  final String ventaId;

  AbonoCubit({required this.dataService, required this.ventaId})
      : super(const AbonoState()) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final metodos = List.of(dataService.metodosPagoActivos);
    final actual = state.selectedMetodoPagoId;
    final seleccionado = metodos.any((m) => m.id == actual) ? actual : metodos.firstOrNull?.id;
    emit(AbonoState(
      status: state.status,
      venta: dataService.ventas.where((v) => v.id == ventaId).firstOrNull,
      metodosPago: metodos,
      selectedMetodoPagoId: seleccionado,
      tasaAutomatica: dataService.tasaVigenteEnMonedaBase,
      tasaManual: dataService.tasaManualOrganizacion(dataService.currentOrganizacionId ?? ''),
      usarTasaManual: state.usarTasaManual,
      errorMonto: state.errorMonto,
      resultado: state.resultado,
    ));
  }

  void seleccionarMetodo(String metodoPagoId) {
    emit(state.copyWith(selectedMetodoPagoId: metodoPagoId));
  }

  void setUsarTasaManual(bool value) {
    emit(state.copyWith(usarTasaManual: value));
  }

  /// Limpia el error del monto cuando el usuario lo vuelve a editar.
  void montoCambiado() {
    if (state.errorMonto != null) emit(state.copyWith(clearErrorMonto: true));
  }

  /// Limpia el mensaje ya mostrado, para que el mismo error pueda volver a
  /// emitirse (un estado igual al anterior no se emite).
  void mensajeMostrado() {
    if (state.errorMessage != null) emit(state.copyWith());
  }

  /// Registra el abono. Si [montoTexto] supera la deuda y el usuario todavía
  /// no lo aceptó ([excedenteConfirmado]), no guarda nada: emite
  /// [AbonoState.excedentePorConfirmar] para que la vista pregunte.
  Future<void> registrar(String montoTexto, {bool excedenteConfirmado = false}) async {
    if (state.isProcessing) return;

    final monto = double.tryParse(montoTexto.trim().replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      emit(state.copyWith(errorMonto: 'Ingresá un monto mayor a 0 (ej: 10.00)'));
      return;
    }
    final metodoPagoId = state.selectedMetodoPagoId;
    if (metodoPagoId == null) {
      emit(state.copyWith(errorMessage: 'No hay métodos de pago activos. Activá uno en Métodos de Pago.'));
      return;
    }
    final venta = state.venta;
    if (venta == null) {
      emit(state.copyWith(errorMessage: 'La factura ya no existe.'));
      return;
    }
    final excedente = monto - venta.deudaUsd;
    if (excedente > 0.005 && !excedenteConfirmado) {
      emit(state.copyWith(excedentePorConfirmar: excedente));
      return;
    }

    emit(state.copyWith(status: AbonoStatus.procesando, clearErrorMonto: true));
    try {
      final resultado = await dataService.registrarAbono(
        ventaId,
        monto,
        metodoPagoId: metodoPagoId,
        usarTasaManual: state.usarTasaManual,
      );
      if (isClosed) return;
      emit(state.copyWith(status: AbonoStatus.terminado, resultado: resultado));
    } catch (e, stackTrace) {
      Logger.error('AbonoCubit: error al registrar abono en $ventaId', e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(
        status: AbonoStatus.editando,
        errorMessage: 'Error al procesar el abono: $e',
      ));
    }
  }

  /// El usuario no aceptó el excedente: no se guarda nada.
  void excedenteDescartado() {
    if (state.excedentePorConfirmar != null) emit(state.copyWith());
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
