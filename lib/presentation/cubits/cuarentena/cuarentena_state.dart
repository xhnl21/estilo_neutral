import 'package:equatable/equatable.dart';
import '../../../models/registro_cuarentena.dart';

enum CuarentenaStatus { initial, loading, success, failure }

/// Estado inmutable para la Bandeja de Cuarentena (BLoC/Cubit).
class CuarentenaState extends Equatable {
  final CuarentenaStatus status;
  final List<RegistroCuarentena> items;
  final String? errorMessage;
  final String? actionSuccessMessage;

  const CuarentenaState({
    this.status = CuarentenaStatus.initial,
    this.items = const [],
    this.errorMessage,
    this.actionSuccessMessage,
  });

  CuarentenaState copyWith({
    CuarentenaStatus? status,
    List<RegistroCuarentena>? items,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return CuarentenaState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  bool get isInitialLoading =>
      (status == CuarentenaStatus.loading || status == CuarentenaStatus.initial) &&
      items.isEmpty;

  @override
  List<Object?> get props => [
        status,
        items,
        errorMessage,
        actionSuccessMessage,
      ];
}
