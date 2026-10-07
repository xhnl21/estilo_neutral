import 'package:equatable/equatable.dart';

enum PushStatus {
  /// Firebase sin configurar o plataforma sin soporte.
  noDisponible,

  /// Sin sesión: no hay dispositivo registrado.
  inactivo,

  /// El usuario no dio permiso para mostrar notificaciones.
  sinPermiso,

  /// Dispositivo registrado en la hoja "dispositivos".
  registrado,

  /// No se pudo registrar (sin red, servidor…); se reintenta en el próximo
  /// inicio de sesión o renovación del token.
  error,
}

/// Estado de las notificaciones push del dispositivo.
class PushState extends Equatable {
  final PushStatus status;
  final String? mensajeError;

  const PushState({this.status = PushStatus.inactivo, this.mensajeError});

  @override
  List<Object?> get props => [status, mensajeError];
}
