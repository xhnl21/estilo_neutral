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

  /// Carga la previsualización de la compensación (Frase 3 de la narrativa)
  Future<void> loadPreview({
    required String clienteId,
    required String ventaDestinoId,
    required double deudaVenta,
  }) async {
    emit(state.copyWith(status: ApplyCreditStatus.loading));
    try {
      final preview = await _previewUseCase(
        clienteId: clienteId,
        ventaDestinoId: ventaDestinoId,
        deudaVenta: deudaVenta,
      );
      emit(state.copyWith(
        status: ApplyCreditStatus.previewReady,
        preview: preview,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ApplyCreditStatus.failure,
        errorMessage: 'Error al previsualizar compensación: $e',
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
    emit(state.copyWith(status: ApplyCreditStatus.loading));
    try {
      final result = await _applyUseCase.execute(
        clienteId: clienteId,
        targetVentaId: ventaDestinoId,
        deudaVenta: deudaVenta,
        userEmail: userEmail,
      );

      if (result.isSuccess) {
        emit(state.copyWith(
          status: ApplyCreditStatus.success,
          result: result,
          successMessage: 'Saldo aplicado. Factura #$ventaDestinoId marcada como Pagada.',
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
