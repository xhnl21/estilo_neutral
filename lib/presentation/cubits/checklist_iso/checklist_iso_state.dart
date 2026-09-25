import 'package:equatable/equatable.dart';
import '../../../models/checklist_iso.dart';

enum ChecklistIsoStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo Checklist ISO (BLoC/Cubit).
class ChecklistIsoState extends Equatable {
  final ChecklistIsoStatus status;
  final List<ChecklistISO> items;
  final int totalConformes;
  final int porcentaje;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const ChecklistIsoState({
    this.status = ChecklistIsoStatus.initial,
    this.items = const [],
    this.totalConformes = 0,
    this.porcentaje = 0,
    this.errorMessage,
    this.actionSuccessMessage,
  });

  ChecklistIsoState copyWith({
    ChecklistIsoStatus? status,
    List<ChecklistISO>? items,
    int? totalConformes,
    int? porcentaje,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return ChecklistIsoState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalConformes: totalConformes ?? this.totalConformes,
      porcentaje: porcentaje ?? this.porcentaje,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == ChecklistIsoStatus.loading || status == ChecklistIsoStatus.initial) &&
      items.isEmpty;

  @override
  List<Object?> get props => [
        status,
        items,
        totalConformes,
        porcentaje,
        errorMessage,
        actionSuccessMessage,
      ];
}
