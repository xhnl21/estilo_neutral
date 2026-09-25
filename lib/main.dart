import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app/di/injection.dart';
import 'app/app.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Oculta la barra de estado/navegación lo antes posible para evitar el
  // parpadeo entre el splash nativo (fullscreen) y el splash de video de
  // Flutter, que también corre en modo inmersivo.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  ServiceLocator().init();
  runApp(const EstiloNeutralApp());
}
