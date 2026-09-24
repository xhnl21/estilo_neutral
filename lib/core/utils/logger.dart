import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Tipos de eventos registrados en el log de la aplicación.
enum LogType {
  debug,
  info,
  warning,
  error,
  success,
}

/// Servicio de Logging centralizado, seguro y estructurado para Flutter.
///
/// Características principales:
/// - **Sanitización de PII y secretos**: Ofuscación automática de correos electrónicos,
///   tokens JWT y claves sensibles en JSON o texto plano (passwords, PINs, tokens, etc.).
/// - **Control de entorno**: Por defecto, los logs se silencian completamente en entornos de
///   producción a menos que se habiliten mediante variables de compilación (`DEBUG_MODE=true`,
///   `ENABLE_LOGS=true`) o mediante [Logger.initialize].
/// - **Alto rendimiento y fiabilidad**: Hace uso de [debugPrint] para evitar truncamiento
///   de buffers en consolas nativas Android/iOS.
abstract final class Logger {
  // Constantes de compilación leídas desde variables de entorno (--dart-define o --dart-define-from-file).
  static const bool _envDebugMode = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: false,
  );

  static const bool _envEnableLogs = bool.fromEnvironment(
    'ENABLE_LOGS',
    defaultValue: false,
  );

  static const String _envEnvironment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: '',
  );

  // Estado mutable interno configurable mediante Logger.initialize
  static bool? _customEnableLogs;
  static bool? _customShowStackTrace;

  /// Expresiones regulares pre-compiladas para sanitización de alto rendimiento
  static final RegExp _emailRegex = RegExp(
    r'([a-zA-Z0-9_.+-]{1,2})[a-zA-Z0-9_.+-]*(@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)',
    caseSensitive: false,
  );

  static final RegExp _jwtRegex = RegExp(
    r'eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]+',
    caseSensitive: false,
  );

  static final RegExp _sensitiveKeysJsonRegex = RegExp(
    r'''("?(?:password|pin|refresh_token|access_token|secret|api_key|cvv)"?\s*[:=]\s*)("(?:\\"|[^"])*"|'(?:\\'|[^'])*'|[^\s,;\}]+)''',
    caseSensitive: false,
  );

  static final RegExp _authorizationRegex = RegExp(
    r'''("?authorization"?\s*[:=]\s*)(Bearer\s+)?("(?:\\"|[^"])*"|'(?:\\'|[^'])*'|[^\s,;\}]+)''',
    caseSensitive: false,
  );

  static final RegExp _genericTokenRegex = RegExp(
    r'''("?token"?\s*[:=]\s*)("(?:\\"|[^"])*"|'(?:\\'|[^'])*'|[^\s,;\}]+)''',
    caseSensitive: false,
  );

  /// Determina si los logs deben emitirse según la configuración activa.
  ///
  /// En producción (`ENVIRONMENT=prod` o `kReleaseMode`), permanece apagado
  /// a menos que se fuerce explícitamente con `ENABLE_LOGS=true` o `initialize(enableLogs: true)`.
  static bool get isLoggingEnabled {
    if (_customEnableLogs != null) return _customEnableLogs!;

    final isProd = _envEnvironment.toLowerCase() == 'prod' ||
        _envEnvironment.toLowerCase() == 'production';

    if (isProd) {
      return _envEnableLogs;
    }

    return _envDebugMode || _envEnableLogs || kDebugMode;
  }

  /// Determina si se deben imprimir los StackTraces completos.
  static bool get shouldShowStackTrace {
    if (_customShowStackTrace != null) return _customShowStackTrace!;
    return kDebugMode || _envDebugMode;
  }

  /// Inicializa o redefine el comportamiento del Logger en tiempo de ejecución.
  ///
  /// [enableLogs] Fuerza el encendido o apagado general de los logs.
  /// [showStackTrace] Controla si se desglosa el stack trace en errores.
  static void initialize({
    bool? enableLogs,
    bool? showStackTrace,
  }) {
    _customEnableLogs = enableLogs;
    _customShowStackTrace = showStackTrace;
  }

  /// Despachador general de logs tipados y sanitizados.
  static void log({
    required String message,
    LogType type = LogType.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!isLoggingEnabled) return;

    final sanitizedMessage = sanitize(message);
    final timestamp = DateTime.now().toIso8601String();
    final badge = _resolveBadge(type);
    final formattedLog = '[$timestamp] $badge $sanitizedMessage';

    debugPrint(formattedLog);

    if (error != null) {
      final sanitizedError = sanitize(error.toString());
      debugPrint('   └─ Cause: $sanitizedError');
    }

    if (stackTrace != null && shouldShowStackTrace) {
      debugPrint('   └─ StackTrace:\n$stackTrace');
    }
  }

  /// 🐛 Log detallado para depuración en desarrollo.
  static void debug(String message) {
    log(message: message, type: LogType.debug);
  }

  /// ℹ️ Información general sobre el flujo normal de la app.
  static void info(String message) {
    log(message: message, type: LogType.info);
  }

  /// ⚠️ Advertencias sobre situaciones inesperadas no bloqueantes.
  static void warning(String message) {
    log(message: message, type: LogType.warning);
  }

  /// ❌ Registro de fallos, excepciones y anomalías con soporte de StackTrace.
  static void error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    log(
      message: message,
      type: LogType.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// ✅ Registro de operaciones completadas exitosamente.
  static void success(String message) {
    log(message: message, type: LogType.success);
  }

  /// ⬆️ / ⬇️ Registro estructurado de peticiones y respuestas de red (HTTP/REST).
  static void api(String message, {bool isRequest = true}) {
    if (!isLoggingEnabled) return;
    final prefix = isRequest ? '⬆️ [API-REQ]' : '⬇️ [API-RES]';
    final timestamp = DateTime.now().toIso8601String();
    final sanitized = sanitize(message);
    debugPrint('[$timestamp] $prefix $sanitized');
  }

  /// 📦 Inspección legible y formateada de objetos, modelos y mapas JSON.
  static void object(String tag, dynamic object) {
    if (!isLoggingEnabled) return;

    String content;
    try {
      if (object is Map || object is List) {
        const encoder = JsonEncoder.withIndent('  ');
        content = encoder.convert(_truncarValoresLargos(object));
      } else {
        content = _truncarValoresLargos(object.toString()) as String;
      }
    } catch (_) {
      content = object.toString();
    }

    final sanitized = sanitize(content);
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[$timestamp] 📦 [$tag]:\n$sanitized');
  }

  /// Reemplaza cadenas muy largas (ej. imágenes en base64) por un resumen,
  /// para que loguear un payload grande no inunde la consola con miles de
  /// caracteres ilegibles. Preserva la estructura del Map/List original.
  static const int _maxStringLengthEnLog = 300;

  /// Trunca una cadena larga para armar mensajes de [api] a mano sin
  /// inundar la consola (p.ej. el body crudo de una respuesta HTTP). Para
  /// loguear un objeto/Map completo, usar [object] en su lugar.
  static String truncate(String value) => _truncarValoresLargos(value) as String;

  static dynamic _truncarValoresLargos(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _truncarValoresLargos(v)));
    }
    if (value is List) {
      return value.map(_truncarValoresLargos).toList();
    }
    if (value is String && value.length > _maxStringLengthEnLog) {
      return '${value.substring(0, _maxStringLengthEnLog)}… (${value.length} caracteres en total, truncado)';
    }
    return value;
  }

  /// Sanitiza una cadena ofuscando información personal identificable (PII) y credenciales.
  ///
  /// - Emails: `usuario@dominio.com` -> `us***@dominio.com`
  /// - JWTs: `eyJhbGci...` -> `eyJ***.***.***`
  /// - Claves sensibles en JSON/Query: `"password": "123"` -> `"password": "***"`
  static String sanitize(String input) {
    if (input.isEmpty) return input;

    // 1. Ofuscación de JWT
    var result = input.replaceAll(_jwtRegex, 'eyJ***.***.***');

    // 2. Ofuscación de correos electrónicos
    result = result.replaceAllMapped(_emailRegex, (match) {
      final prefix = match.group(1) ?? '';
      final domain = match.group(2) ?? '';
      return '$prefix***$domain';
    });

    // 3. Ofuscación de pares clave-valor sensibles (JSON / URL params / texto)
    result = result.replaceAllMapped(_sensitiveKeysJsonRegex, (match) {
      final keyPart = match.group(1) ?? '';
      return '$keyPart"***"';
    });

    // 4. Ofuscación de Authorization (Bearer o tokens estándar)
    result = result.replaceAllMapped(_authorizationRegex, (match) {
      final keyPart = match.group(1) ?? '';
      final bearerPart = match.group(2) ?? '';
      final val = match.group(3) ?? '';
      if (val.contains('eyJ***.***.***') || val.contains('***')) {
        return match.group(0)!;
      }
      return '$keyPart$bearerPart"***"';
    });

    // 5. Ofuscación de claves token en JSON o texto plano
    result = result.replaceAllMapped(_genericTokenRegex, (match) {
      final keyPart = match.group(1) ?? '';
      final val = match.group(2) ?? '';
      if (val.contains('eyJ***.***.***') || val.contains('***')) {
        return match.group(0)!;
      }
      return '$keyPart"***"';
    });

    return result;
  }

  static String _resolveBadge(LogType type) {
    return switch (type) {
      LogType.debug => '🐛 [DEBUG]',
      LogType.info => 'ℹ️ [INFO]',
      LogType.warning => '⚠️ [WARNING]',
      LogType.error => '❌ [ERROR]',
      LogType.success => '✅ [SUCCESS]',
    };
  }
}
