// Archivo provisorio. Firebase se inicializa primero con la configuración
// nativa (android/app/google-services.json, ios/Runner/GoogleService-Info.plist);
// este archivo es el respaldo y lo reemplaza `flutterfire configure` si se
// prefiere (ver informe.md, "Notificaciones FCM").
//
// Mientras sea este archivo y no haya configuración nativa, la app arranca
// igual y las notificaciones quedan desactivadas (PushNoDisponible).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase todavía no está configurado: corré `flutterfire configure` '
      '(ver informe.md, "Notificaciones FCM").',
    );
  }
}
