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

  const ApplyCreditState({
    this.status = ApplyCreditStatus.initial,
    this.preview,
    this.result,
    this.errorMessage,
    this.successMessage,
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
  }) {
    return ApplyCreditState(
      status: status ?? this.status,
      preview: preview ?? this.preview,
      result: result ?? this.result,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        preview,
        result,
        errorMessage,
        successMessage,
      ];
}
