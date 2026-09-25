import 'package:equatable/equatable.dart';
import '../../../../models/resumen_diario.dart';

enum ReportingStatus { initial, loading, success, failure }

/// Estado inmutable para Resumen Diario / Reporting (BLoC/Cubit).
class ReportingState extends Equatable {
  final ReportingStatus status;
  final List<ResumenDiario> resumenesDiarios;
  final bool isLoading;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ReportingState({
    this.status = ReportingStatus.initial,
    this.resumenesDiarios = const [],
    this.isLoading = false,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  double get totalVentasUsd =>
      resumenesDiarios.fold<double>(0.0, (s, r) => s + r.totalUsd);

  double get totalBs =>
      resumenesDiarios.fold<double>(0.0, (s, r) => s + r.totalBs);

  ReportingState copyWith({
    ReportingStatus? status,
    List<ResumenDiario>? resumenesDiarios,
    bool? isLoading,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return ReportingState(
      status: status ?? this.status,
      resumenesDiarios: resumenesDiarios ?? this.resumenesDiarios,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        resumenesDiarios,
        isLoading,
        errorMessage,
        actionSuccessMessage,
      ];
}
