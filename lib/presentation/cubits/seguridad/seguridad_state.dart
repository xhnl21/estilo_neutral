import 'package:equatable/equatable.dart';

enum SeguridadStatus { initial, loading, success, failure }

/// Estado inmutable para el módulo de Seguridad (BLoC/Cubit).
class SeguridadState extends Equatable {
  final SeguridadStatus status;
  final String? metodoActivo;
  final bool cargandoCapacidades;
  final bool biometricoDisponible;
  final bool faceIdDisponible;
  final String? errorMessage;

  const SeguridadState({
    this.status = SeguridadStatus.initial,
    this.metodoActivo,
    this.cargandoCapacidades = true,
    this.biometricoDisponible = false,
    this.faceIdDisponible = false,
    this.errorMessage,
  });

  SeguridadState copyWith({
    SeguridadStatus? status,
    String? metodoActivo,
    bool clearMetodoActivo = false,
    bool? cargandoCapacidades,
    bool? biometricoDisponible,
    bool? faceIdDisponible,
    String? errorMessage,
  }) {
    return SeguridadState(
      status: status ?? this.status,
      metodoActivo: clearMetodoActivo ? null : (metodoActivo ?? this.metodoActivo),
      cargandoCapacidades: cargandoCapacidades ?? this.cargandoCapacidades,
      biometricoDisponible: biometricoDisponible ?? this.biometricoDisponible,
      faceIdDisponible: faceIdDisponible ?? this.faceIdDisponible,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        metodoActivo,
        cargandoCapacidades,
        biometricoDisponible,
        faceIdDisponible,
        errorMessage,
      ];
}
