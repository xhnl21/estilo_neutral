import 'package:equatable/equatable.dart';
import '../../../models/audit_log.dart';

enum AuditLogStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Bitácora de Auditoría (BLoC/Cubit).
class AuditLogState extends Equatable {
  final AuditLogStatus status;
  final List<AuditLog> logs;
  final List<AuditLog> filteredLogs;
  final String selectedHoja;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const AuditLogState({
    this.status = AuditLogStatus.initial,
    this.logs = const [],
    this.filteredLogs = const [],
    this.selectedHoja = 'Todas',
    this.errorMessage,
    this.actionSuccessMessage,
  });

  AuditLogState copyWith({
    AuditLogStatus? status,
    List<AuditLog>? logs,
    List<AuditLog>? filteredLogs,
    String? selectedHoja,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return AuditLogState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      filteredLogs: filteredLogs ?? this.filteredLogs,
      selectedHoja: selectedHoja ?? this.selectedHoja,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == AuditLogStatus.loading || status == AuditLogStatus.initial) &&
      logs.isEmpty;

  @override
  List<Object?> get props => [
        status,
        logs,
        filteredLogs,
        selectedHoja,
        errorMessage,
        actionSuccessMessage,
      ];
}
