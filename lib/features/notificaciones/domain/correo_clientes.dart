import 'package:equatable/equatable.dart';

/// Por dónde se envía una notificación guardada.
enum CanalEnvio { notificacion, correo }

/// Resultado de un envío de correo a clientes, tal como lo informa el servidor.
class ResultadoEnvioCorreo extends Equatable {
  /// ID de la fila en la hoja "correos".
  final String id;
  final int enviados;
  final int fallidos;

  /// Correos que Google todavía permite enviar hoy (cupo de MailApp).
  final int? restantes;

  const ResultadoEnvioCorreo({required this.id, required this.enviados, required this.fallidos, this.restantes});

  @override
  List<Object?> get props => [id, enviados, fallidos, restantes];
}
