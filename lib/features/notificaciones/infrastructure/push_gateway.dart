import 'dart:async';

/// Una notificación recibida.
class MensajePush {
  final String? titulo;
  final String? cuerpo;

  /// Datos extra. `ruta` (si viene) es la pantalla a abrir al tocarla.
  final Map<String, String> datos;

  const MensajePush({this.titulo, this.cuerpo, this.datos = const {}});

  String? get ruta => datos['ruta'];

  /// Aviso silencioso del servidor: la cuenta fue inactivada o eliminada y
  /// hay que cerrar la sesión. No se muestra.
  bool get esSesionRevocada => datos['tipo'] == tipoSesionRevocada;

  /// Push silencioso del servidor (sesión revocada, límites o uso de las
  /// notificaciones): la app lo atiende sin mostrar nada.
  bool get esSilencioso => tiposSilenciosos.contains(datos['tipo']);
}

/// Valor de `tipo` del push silencioso que envía el Apps Script
/// (`_expulsarUsuario`) al inactivar o eliminar un usuario.
const tipoSesionRevocada = 'sesion_revocada';

/// Cambiaron los límites de notificaciones de alguna organización
/// (TIPO_CONFIG_NOTIFICACIONES en el Apps Script).
const tipoConfigNotificaciones = 'config_notificaciones';

/// Alguien de la organización gastó parte del cupo compartido
/// (TIPO_USO_NOTIFICACIONES en el Apps Script).
const tipoUsoNotificaciones = 'uso_notificaciones';

const tiposSilenciosos = {tipoSesionRevocada, tipoConfigNotificaciones, tipoUsoNotificaciones};

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

  /// `true` si, con la app en segundo plano o cerrada, llegó un aviso de
  /// sesión revocada que todavía no se atendió. Lo borra al leerlo.
  Future<bool> consumirAvisoRevocacion();
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
  @override
  Future<bool> consumirAvisoRevocacion() async => false;
}
