import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

/// Mensajes que llegan con la app cerrada o en segundo plano: el sistema ya
/// muestra la notificación; acá no hace falta hacer nada más. Tiene que ser
/// una función de nivel superior (corre en otro isolate).
@pragma('vm:entry-point')
Future<void> manejadorSegundoPlano(RemoteMessage mensaje) async {
  await _inicializarFirebase();
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
    await locales.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notificacion'),
        // El permiso se pide después del login (PushCubit), no al arrancar.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        final ruta = respuesta.payload;
        push._abiertosLocales.add(MensajePush(datos: {if (ruta != null && ruta.isNotEmpty) 'ruta': ruta}));
      },
    );
    await locales
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canalGeneral);
    // iOS: con la app abierta, la notificación la muestra el sistema.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    return push;
  }

  static MensajePush _convertir(RemoteMessage m) => MensajePush(
        titulo: m.notification?.title,
        cuerpo: m.notification?.body,
        datos: m.data.map((k, v) => MapEntry(k, '$v')),
      );

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
    return m == null ? null : _convertir(m);
  }

  @override
  Future<void> mostrarLocal(MensajePush mensaje) async {
    // En iOS la muestra el sistema (setForegroundNotificationPresentationOptions).
    if (Platform.isIOS) return;
    await _locales.show(
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
        ),
      ),
      payload: mensaje.ruta,
    );
  }

  @override
  Future<void> eliminarToken() => _fcm.deleteToken();
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
