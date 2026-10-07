import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app/di/injection.dart';
import 'app/app.dart';
import 'features/notificaciones/infrastructure/push_firebase.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Oculta la barra de estado/navegación lo antes posible para evitar el
  // parpadeo entre el splash nativo (fullscreen) y el splash de video de
  // Flutter, que también corre en modo inmersivo.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Notificaciones FCM: si Firebase no está configurado, la app arranca igual
  // sin ellas (ver docs/notificaciones-fcm.md).
  final push = await PushFirebase.inicializar();
  ServiceLocator().init(push: push);
  runApp(const EstiloNeutralApp());
}
