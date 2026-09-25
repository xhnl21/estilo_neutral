import 'package:equatable/equatable.dart';
import '../../../models/reporte_migracion.dart';

enum ReporteMigracionStatus { initial, loading, success, failure }

/// Estado inmutable para Reporte de Migración (BLoC/Cubit).
class ReporteMigracionState extends Equatable {
  final ReporteMigracionStatus status;
  final List<ReporteMigracion> reportes;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ReporteMigracionState({
    this.status = ReporteMigracionStatus.initial,
    this.reportes = const [],
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ReporteMigracionState copyWith({
    ReporteMigracionStatus? status,
    List<ReporteMigracion>? reportes,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return ReporteMigracionState(
      status: status ?? this.status,
      reportes: reportes ?? this.reportes,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == ReporteMigracionStatus.loading || status == ReporteMigracionStatus.initial) &&
      reportes.isEmpty;

  @override
  List<Object?> get props => [
        status,
        reportes,
        errorMessage,
        actionSuccessMessage,
      ];
}
