import 'package:equatable/equatable.dart';

/// A quién va una notificación FCM.
enum AlcanceNotificacion {
  /// Todos los dispositivos de todos los usuarios con acceso.
  global,

  /// Todos los usuarios de una o más organizaciones.
  organizaciones,

  /// Usuarios puntuales (de una o varias organizaciones).
  usuarios,
}

/// Destinatarios de una notificación. El servidor resuelve los dispositivos:
/// solo de usuarios que siguen teniendo acceso, y por la organización a la
/// que pertenecen hoy (no la que tenían al registrar el dispositivo).
class DestinoNotificacion extends Equatable {
  final AlcanceNotificacion alcance;
  final Set<String> organizacionIds;
  final Set<String> usuarioEmails;

  const DestinoNotificacion._(this.alcance, this.organizacionIds, this.usuarioEmails);

  const DestinoNotificacion.global() : this._(AlcanceNotificacion.global, const {}, const {});

  /// Una o varias organizaciones.
  DestinoNotificacion.organizaciones(Iterable<String> ids)
      : this._(AlcanceNotificacion.organizaciones, Set.unmodifiable(ids), const {});

  /// Uno o varios usuarios (de cualquier organización).
  DestinoNotificacion.usuarios(Iterable<String> emails)
      : this._(
          AlcanceNotificacion.usuarios,
          const {},
          Set.unmodifiable(emails.map((e) => e.trim().toLowerCase())),
        );

  /// Mensaje de error si el destino no tiene a quién enviar, o `null`.
  String? get error => switch (alcance) {
        AlcanceNotificacion.global => null,
        AlcanceNotificacion.organizaciones =>
          organizacionIds.isEmpty ? 'Elegí al menos una organización.' : null,
        AlcanceNotificacion.usuarios => usuarioEmails.isEmpty ? 'Elegí al menos un usuario.' : null,
      };

  Map<String, dynamic> toMap() => {
        'alcance': alcance.name,
        if (alcance == AlcanceNotificacion.organizaciones) 'organizacion_ids': organizacionIds.toList(),
        if (alcance == AlcanceNotificacion.usuarios) 'usuarios': usuarioEmails.toList(),
      };

  @override
  List<Object?> get props => [alcance, organizacionIds.toList()..sort(), usuarioEmails.toList()..sort()];
}

/// El servidor rechazó el envío porque se agotó el cupo del período (código
/// `limite_notificaciones`). Es un [StateError] como los demás rechazos.
class LimiteNotificacionesAgotado extends StateError {
  LimiteNotificacionesAgotado(super.message);
}

/// Resultado de un envío, tal como lo informa el servidor.
class ResultadoEnvioNotificacion extends Equatable {
  /// ID de la fila en la hoja "notificaciones".
  final String id;
  final int enviados;
  final int fallidos;

  const ResultadoEnvioNotificacion({required this.id, required this.enviados, required this.fallidos});

  bool get sinDestinatarios => enviados == 0 && fallidos == 0;

  @override
  List<Object?> get props => [id, enviados, fallidos];
}
