import 'package:flutter/foundation.dart';

/// Lista blanca de correos de Google autorizados a iniciar sesión en la app.
///
/// El login con Google por sí solo solo prueba que la persona tiene una cuenta
/// de Google válida, no que esté autorizada a operar los datos del negocio
/// (`clientes`, `ventas`, `inventario`, etc.). Esta lista es el control real
/// de acceso post-login.
abstract final class AccessControlConfig {
  /// Lista separada por comas leída desde `--dart-define=ALLOWED_EMAILS=...`
  /// o archivos `.env` (vía `--dart-define-from-file`).
  static const String _envAllowedEmails = String.fromEnvironment(
    'ALLOWED_EMAILS',
    defaultValue: 'neidapulgar1989@gmail.com,xhnl21@gmail.com',
  );

  /// Sobrescritura programática para pruebas unitarias y de widgets.
  static List<String>? _overrideAllowedEmails;

  @visibleForTesting
  static void setOverrideAllowedEmails(List<String>? emails) {
    _overrideAllowedEmails = emails;
  }

  /// Correos autorizados, normalizados a minúsculas y sin espacios.
  static List<String> get allowedEmails {
    final raw = _overrideAllowedEmails ??
        _envAllowedEmails
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    return raw.map((e) => e.toLowerCase()).toList();
  }

  /// Indica si [email] está autorizado a operar la aplicación.
  static bool isEmailAllowed(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return allowedEmails.contains(normalized);
  }
}
