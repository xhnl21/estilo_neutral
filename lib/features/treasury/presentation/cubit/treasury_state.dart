import 'package:equatable/equatable.dart';
import '../../../../models/compra_divisa.dart';

enum TreasuryStatus { initial, loading, success, failure }

/// Estado inmutable para Tesorería (BLoC/Cubit).
class TreasuryState extends Equatable {
  final TreasuryStatus status;
  final List<CompraDivisa> comprasDivisas;
  final bool isLoading;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const TreasuryState({
    this.status = TreasuryStatus.initial,
    this.comprasDivisas = const [],
    this.isLoading = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  double get totalUsd =>
      comprasDivisas.fold<double>(0.0, (s, c) => s + c.capitalUsd);

  double get totalComisiones =>
      comprasDivisas.fold<double>(0.0, (s, c) => s + c.comisionBinanceUsd);

  TreasuryState copyWith({
    TreasuryStatus? status,
    List<CompraDivisa>? comprasDivisas,
    bool? isLoading,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return TreasuryState(
      status: status ?? this.status,
      comprasDivisas: comprasDivisas ?? this.comprasDivisas,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        comprasDivisas,
        isLoading,
        errorMessage,
        actionSuccessMessage,
      ];
}
