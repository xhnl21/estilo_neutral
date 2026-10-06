import 'package:equatable/equatable.dart';
import '../../domain/value_objects/apply_credit_plan.dart';

enum ApplyCreditStatus { initial, loading, previewReady, success, failure }

/// Estado inmutable para el flujo de compensación y aplicación de saldo a favor.
class ApplyCreditState extends Equatable {
  final ApplyCreditStatus status;
  final ApplyCreditPreview? preview;
  final ApplyCreditResult? result;
  final String? errorMessage;
  final String? successMessage;

  /// `true` si el último fallo fue al cargar la vista previa (no al aplicar):
  /// la vista ofrece reintentar SOLO la vista previa, nunca aplicar el
  /// crédito sin que el usuario toque "Confirmar aplicación".
  final bool falloVistaPrevia;

  /// Deuda de la factura al momento de la vista previa, leída de los datos
  /// actuales (no la que se vio al abrir la pantalla).
  final double? deudaVenta;

  const ApplyCreditState({
    this.status = ApplyCreditStatus.initial,
    this.preview,
    this.result,
    this.errorMessage,
    this.successMessage,
    this.falloVistaPrevia = false,
    this.deudaVenta,
  });

  bool get isLoading => status == ApplyCreditStatus.loading;
  bool get isSuccess => status == ApplyCreditStatus.success;
  bool get isFailure => status == ApplyCreditStatus.failure;

  ApplyCreditState copyWith({
    ApplyCreditStatus? status,
    ApplyCreditPreview? preview,
    ApplyCreditResult? result,
    String? errorMessage,
    String? successMessage,
    bool? falloVistaPrevia,
    double? deudaVenta,
  }) {
    return ApplyCreditState(
      status: status ?? this.status,
      preview: preview ?? this.preview,
      result: result ?? this.result,
      errorMessage: errorMessage,
      successMessage: successMessage,
      falloVistaPrevia: falloVistaPrevia ?? false,
      deudaVenta: deudaVenta ?? this.deudaVenta,
    );
  }

  @override
  List<Object?> get props => [
        status,
        preview,
        result,
        errorMessage,
        successMessage,
        falloVistaPrevia,
        deudaVenta,
      ];
}
