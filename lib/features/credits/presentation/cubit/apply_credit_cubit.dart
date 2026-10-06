import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/usecases/apply_client_credit.dart';
import '../../application/usecases/preview_apply_credit.dart';
import '../../domain/repositories/client_credit_repository.dart';
import 'apply_credit_state.dart';

/// Cubit para la compensación y aplicación de saldo a favor según reglas BLoC estrictas.
class ApplyCreditCubit extends Cubit<ApplyCreditState> {
  final ClientCreditRepository repository;
  final SheetsDataService dataService;
  late final PreviewApplyCredit _previewUseCase;
  late final ApplyClientCredit _applyUseCase;

  ApplyCreditCubit({
    required this.repository,
    required this.dataService,
  }) : super(const ApplyCreditState()) {
    _previewUseCase = PreviewApplyCredit(repository: repository);
    _applyUseCase = ApplyClientCredit(repository: repository);
    dataService.addListener(_onDataServiceChanged);
  }

  void _onDataServiceChanged() {
    // Escucha cambios en dataService si es necesario
  }

  /// Deuda de [ventaId] según los datos actuales; [respaldo] si la venta ya
  /// no está cargada.
  double _deudaActual(String ventaId, double respaldo) {
    final venta = dataService.ventas.where((v) => v.id == ventaId).firstOrNull;
    if (venta == null) return respaldo;
    return (venta.totalPagarUsd - venta.abonoUsd).clamp(0.0, double.infinity).toDouble();
  }

  /// Carga la previsualización de la compensación (Frase 3 de la narrativa)
  Future<void> loadPreview({
    required String clienteId,
    required String ventaDestinoId,
    required double deudaVenta,
  }) async {
    if (isClosed) return;
    final deuda = _deudaActual(ventaDestinoId, deudaVenta);
    emit(state.copyWith(status: ApplyCreditStatus.loading, deudaVenta: deuda));
    try {
      final preview = await _previewUseCase(
        clienteId: clienteId,
        ventaDestinoId: ventaDestinoId,
        deudaVenta: deuda,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: ApplyCreditStatus.previewReady,
        preview: preview,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: ApplyCreditStatus.failure,
        errorMessage: 'No se pudo calcular la compensación: $e',
        falloVistaPrevia: true,
      ));
    }
  }

  /// Ejecuta la aplicación de crédito en lote atómico All-or-Nothing
  Future<bool> applyCredit({
    required String clienteId,
    required String ventaDestinoId,
    required double deudaVenta,
    required String userEmail,
  }) async {
    if (isClosed) return false;
    emit(state.copyWith(status: ApplyCreditStatus.loading));
    try {
      final result = await _applyUseCase.execute(
        clienteId: clienteId,
        targetVentaId: ventaDestinoId,
        deudaVenta: _deudaActual(ventaDestinoId, deudaVenta),
        userEmail: userEmail,
      );

      if (isClosed) return result.isSuccess;

      if (result.isSuccess) {
        emit(state.copyWith(
          status: ApplyCreditStatus.success,
          result: result,
          successMessage: result.deudaRestante <= 0
              ? 'Saldo aplicado. Factura #$ventaDestinoId pagada por completo.'
              : 'Saldo aplicado (USD ${result.montoAplicado.toStringAsFixed(2)}). '
                  'La factura #$ventaDestinoId sigue pendiente por USD ${result.deudaRestante.toStringAsFixed(2)}.',
        ));
        return true;
      } else {
        emit(state.copyWith(
          status: ApplyCreditStatus.failure,
          errorMessage: result.errorMessage ?? 'Error desconocido al aplicar el crédito.',
        ));
        return false;
      }
    } catch (e) {
      if (isClosed) return false;
      emit(state.copyWith(
        status: ApplyCreditStatus.failure,
        errorMessage: 'Excepción durante la aplicación: $e',
      ));
      return false;
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
