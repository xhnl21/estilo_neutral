import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/logger.dart';
import '../../../firebase_options.dart';
import 'push_gateway.dart';

/// Canal de Android para las notificaciones de la app. El mismo ID está en
/// AndroidManifest.xml (`default_notification_channel_id`) y lo usa el
/// Apps Script al enviar.
const canalGeneral = AndroidNotificationChannel(
  'estilo_neutral_general',
  'Avisos de Estilo Neutral',
  description: 'Notificaciones enviadas por los usuarios de la organización.',
  importance: Importance.high,
);

/// Dorado del monograma del logo (mismo valor que `color_notificacion` en
/// android/app/src/main/res/values/colors.xml y que el Apps Script).
const colorNotificacion = Color(0xFFBC976F);

/// Dónde el manejador de segundo plano (otro isolate) deja anotado un aviso
/// de sesión revocada para que la app lo atienda al volver a primer plano.
const _almacenAvisos = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
);
const _claveAvisoRevocacion = 'aviso_sesion_revocada';

/// Mensajes que llegan con la app cerrada o en segundo plano. El script
/// envía mensajes **solo de datos** (sin `notification`), así que la
/// notificación la arma la app con la imagen incluida en el APK: no depende
/// de descargar nada (en Xiaomi/MIUI, con la app dormida, la descarga no
/// llegaba a tiempo y salía sin logo). Corre en otro isolate: tiene que ser
/// una función de nivel superior.
@pragma('vm:entry-point')
Future<void> manejadorSegundoPlano(RemoteMessage mensaje) async {
  final recibido = mensajeDesde(mensaje);
  // Push silencioso (cuenta inactivada o eliminada): no se muestra nada; se
  // anota para cerrar la sesión apenas la app vuelva a primer plano.
  if (recibido.esSesionRevocada) {
    await _almacenAvisos.write(key: _claveAvisoRevocacion, value: DateTime.now().toIso8601String());
    return;
  }
  // Otros avisos silenciosos (límites o uso de las notificaciones): con la
  // app cerrada no hay pantalla que refrescar; al entrar al módulo se relee.
  if (recibido.esSilencioso) return;
  // Un mensaje con `notification` (builds o envíos viejos) ya lo muestra el
  // sistema; mostrarlo acá lo duplicaría.
  if (mensaje.notification != null || !Platform.isAndroid) return;
  final locales = FlutterLocalNotificationsPlugin();
  await _inicializarLocales(locales);
  await mostrarNotificacionLocal(locales, recibido);
}

/// Convierte un mensaje de FCM: el texto viene en `notification` (envíos
/// viejos) o en los datos `titulo` y `cuerpo` (envíos actuales).
MensajePush mensajeDesde(RemoteMessage m) {
  final datos = m.data.map((k, v) => MapEntry(k, '$v'));
  return MensajePush(
    titulo: m.notification?.title ?? datos['titulo'],
    cuerpo: m.notification?.body ?? datos['cuerpo'],
    datos: datos,
  );
}

Future<void> _inicializarLocales(
  FlutterLocalNotificationsPlugin locales, {
  void Function(NotificationResponse)? alTocar,
}) async {
  await locales.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notificacion_en'),
      // El permiso se pide después del login (PushCubit), no al arrancar.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: alTocar,
  );
  await locales
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(canalGeneral);
}

/// Muestra la notificación con la marca: monograma "EN" en dorado, logo
/// cuadrado a la derecha y, al expandir, el logo apaisado (2:1). Las dos
/// imágenes van en el APK (drawable-nodpi), no se descargan.
Future<void> mostrarNotificacionLocal(FlutterLocalNotificationsPlugin locales, MensajePush mensaje) async {
  // Un aviso silencioso (o un tipo nuevo que esta versión no conoce) no trae
  // texto: nunca se muestra una notificación vacía.
  if (mensaje.esSilencioso || ((mensaje.titulo ?? '').isEmpty && (mensaje.cuerpo ?? '').isEmpty)) return;
  return locales.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
    title: mensaje.titulo,
    body: mensaje.cuerpo,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        canalGeneral.id,
        canalGeneral.name,
        channelDescription: canalGeneral.description,
        importance: Importance.high,
        priority: Priority.high,
        color: colorNotificacion,
        largeIcon: const DrawableResourceAndroidBitmap('ic_logo_notificacion'),
        styleInformation: BigPictureStyleInformation(
          const DrawableResourceAndroidBitmap('logo_notificacion_2x1'),
          largeIcon: const DrawableResourceAndroidBitmap('ic_logo_notificacion'),
          hideExpandedLargeIcon: true,
          contentTitle: mensaje.titulo,
          summaryText: mensaje.cuerpo,
        ),
      ),
    ),
    payload: mensaje.ruta,
  );
}

/// Inicializa Firebase. Primero con la configuración nativa
/// (android/app/google-services.json, que el plugin resuelve por variante
/// prod/dev/qa, y GoogleService-Info.plist en iOS); si no está, con
/// firebase_options.dart (`flutterfire configure`). Lanza si no hay ninguna.
Future<void> _inicializarFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

/// [PushGateway] con Firebase Cloud Messaging.
class PushFirebase implements PushGateway {
  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _locales;
  final _abiertosLocales = StreamController<MensajePush>.broadcast();

  PushFirebase._(this._fcm, this._locales);

  /// Inicializa Firebase y las notificaciones locales. Si Firebase no está
  /// configurado (firebase_options.dart provisorio) o falla, devuelve
  /// [PushNoDisponible] y la app sigue sin notificaciones.
  static Future<PushGateway> inicializar() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return const PushNoDisponible('Plataforma sin notificaciones push.');
    }
    try {
      await _inicializarFirebase();
    } catch (e) {
      Logger.warning('Notificaciones desactivadas: $e');
      return PushNoDisponible(e.toString());
    }
    FirebaseMessaging.onBackgroundMessage(manejadorSegundoPlano);

    final locales = FlutterLocalNotificationsPlugin();
    final push = PushFirebase._(FirebaseMessaging.instance, locales);
    await _inicializarLocales(locales, alTocar: (respuesta) => push._abiertosLocales.add(_desdeRuta(respuesta.payload)));
    // iOS: con la app abierta, la notificación la muestra el sistema.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    return push;
  }

  static MensajePush _convertir(RemoteMessage m) => mensajeDesde(m);

  static MensajePush _desdeRuta(String? ruta) =>
      MensajePush(datos: {if (ruta != null && ruta.isNotEmpty) 'ruta': ruta});

  @override
  bool get disponible => true;

  @override
  String get plataforma => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<bool> solicitarPermiso() async {
    final ajustes = await _fcm.requestPermission();
    return ajustes.authorizationStatus == AuthorizationStatus.authorized ||
        ajustes.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> obtenerToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      // iOS sin token APNs todavía (simulador, sin capability de push…).
      Logger.warning('No se pudo obtener el token FCM: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRenovado => _fcm.onTokenRefresh;

  @override
  Stream<MensajePush> get mensajesEnPrimerPlano => FirebaseMessaging.onMessage.map(_convertir);

  @override
  Stream<MensajePush> get mensajesAbiertos =>
      StreamGroupSimple.merge([FirebaseMessaging.onMessageOpenedApp.map(_convertir), _abiertosLocales.stream]);

  @override
  Future<MensajePush?> mensajeInicial() async {
    final m = await _fcm.getInitialMessage();
    if (m != null) return _convertir(m);
    // La app se abrió tocando una notificación local (las que arma la app).
    final lanzamiento = await _locales.getNotificationAppLaunchDetails();
    if (lanzamiento?.didNotificationLaunchApp ?? false) {
      return _desdeRuta(lanzamiento!.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<void> mostrarLocal(MensajePush mensaje) async {
    // En iOS la muestra el sistema (setForegroundNotificationPresentationOptions).
    if (Platform.isIOS) return;
    await mostrarNotificacionLocal(_locales, mensaje);
  }

  @override
  Future<void> eliminarToken() => _fcm.deleteToken();

  @override
  Future<bool> consumirAvisoRevocacion() async {
    try {
      final aviso = await _almacenAvisos.read(key: _claveAvisoRevocacion);
      if (aviso == null) return false;
      await _almacenAvisos.delete(key: _claveAvisoRevocacion);
      return true;
    } catch (e) {
      Logger.warning('No se pudo leer el aviso de sesión revocada: $e');
      return false;
    }
  }
}

/// Une varios streams en uno (sin depender de package:async).
abstract final class StreamGroupSimple {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late StreamController<T> controlador;
    final suscripciones = <StreamSubscription<T>>[];
    controlador = StreamController<T>.broadcast(
      onListen: () {
        for (final s in streams) {
          suscripciones.add(s.listen(controlador.add, onError: controlador.addError));
        }
      },
      onCancel: () async {
        for (final s in suscripciones) {
          await s.cancel();
        }
        suscripciones.clear();
      },
    );
    return controlador.stream;
  }
}
