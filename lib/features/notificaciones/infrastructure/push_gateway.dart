import 'dart:async';

/// Una notificación recibida.
class MensajePush {
  final String? titulo;
  final String? cuerpo;

  /// Datos extra. `ruta` (si viene) es la pantalla a abrir al tocarla.
  final Map<String, String> datos;

  const MensajePush({this.titulo, this.cuerpo, this.datos = const {}});

  String? get ruta => datos['ruta'];
}

/// Canal de notificaciones push del dispositivo. Abstrae Firebase para que
/// la lógica (PushCubit) se pueda probar sin él.
abstract class PushGateway {
  /// `false` si Firebase no está configurado o no se pudo inicializar.
  bool get disponible;

  /// `android` o `ios`.
  String get plataforma;

  /// Pide permiso para mostrar notificaciones. `true` si se concedió.
  Future<bool> solicitarPermiso();

  /// Token FCM del dispositivo, o `null` si no hay.
  Future<String?> obtenerToken();

  /// Emite cuando FCM renueva el token.
  Stream<String> get tokenRenovado;

  /// Notificaciones que llegan con la app abierta.
  Stream<MensajePush> get mensajesEnPrimerPlano;

  /// Notificaciones tocadas con la app en segundo plano.
  Stream<MensajePush> get mensajesAbiertos;

  /// Notificación que abrió la app desde cerrada, si la hubo.
  Future<MensajePush?> mensajeInicial();

  /// Muestra una notificación local (FCM no las muestra con la app abierta).
  Future<void> mostrarLocal(MensajePush mensaje);

  /// Invalida el token de este dispositivo (al cerrar sesión).
  Future<void> eliminarToken();
}

/// Canal inactivo: Firebase sin configurar, plataforma sin soporte o error al
/// inicializar. La app funciona igual, sin notificaciones.
class PushNoDisponible implements PushGateway {
  final String motivo;

  const PushNoDisponible(this.motivo);

  @override
  bool get disponible => false;
  @override
  String get plataforma => 'ninguna';
  @override
  Future<bool> solicitarPermiso() async => false;
  @override
  Future<String?> obtenerToken() async => null;
  @override
  Stream<String> get tokenRenovado => const Stream.empty();
  @override
  Stream<MensajePush> get mensajesEnPrimerPlano => const Stream.empty();
  @override
  Stream<MensajePush> get mensajesAbiertos => const Stream.empty();
  @override
  Future<MensajePush?> mensajeInicial() async => null;
  @override
  Future<void> mostrarLocal(MensajePush mensaje) async {}
  @override
  Future<void> eliminarToken() async {}
}
