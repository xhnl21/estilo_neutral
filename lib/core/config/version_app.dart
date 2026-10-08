import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

/// Versión de la app instalada (la de `version:` en pubspec.yaml). Se lee
/// una vez al arrancar ([cargar], desde main.dart): no cambia mientras la
/// app corre, así que no es estado reactivo.
abstract final class VersionApp {
  static String _texto = '';

  /// Por ejemplo `v1.0.0 (2019)`; vacío si no se pudo leer (o en tests).
  static String get texto => _texto;

  static Future<void> cargar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _texto = info.buildNumber.isEmpty ? 'v${info.version}' : 'v${info.version} (${info.buildNumber})';
    } catch (e) {
      Logger.warning('No se pudo leer la versión de la app: $e');
    }
  }
}
