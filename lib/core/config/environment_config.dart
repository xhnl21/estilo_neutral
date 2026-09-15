import 'package:flutter/foundation.dart';

/// Configuración centralizada de entorno y control de visualización de metadatos técnicos.
///
/// Cumplimiento de requerimientos:
/// - Ocultar nombres técnicos de tablas/hojas (ej. `compras_divisas`, `clientes`) en producción.
/// - Ocultar metadatos y enlaces crudos a Google Sheets (`Base de Datos Google Sheets: ...`).
/// - Mostrar dicha información exclusivamente en entornos `dev` y `test` o cuando la variable
///   de entorno `SHOW_TECHNICAL_INFO` sea explícitamente configurada en `true`.
abstract final class EnvironmentConfig {
  /// Identificador del entorno actual ('prod', 'dev', 'test', etc.).
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'prod',
  );

  /// Bandera explícita leída desde `--dart-define=SHOW_TECHNICAL_INFO=true/false` o archivos `.env`.
  static const bool _envShowTechnicalInfo = bool.fromEnvironment(
    'SHOW_TECHNICAL_INFO',
    defaultValue: false,
  );

  /// Sobrescritura programática para pruebas unitarias y de widgets.
  static bool? _overrideShowTechnicalInfo;

  /// Permite establecer una sobrescritura para tests sin modificar variables de compilación.
  @visibleForTesting
  static void setOverrideShowTechnicalInfo(bool? value) {
    _overrideShowTechnicalInfo = value;
  }

  /// Determina si la aplicación debe mostrar información técnica interna:
  /// - Nombres técnicos de hojas de cálculo (`compras_divisas`, `inventario`, etc.).
  /// - Metadatos de la base de datos de Google Sheets (identificadores y URLs).
  /// - Prefijos forenses o técnicos en subtítulos de vistas ("Hoja ... • ...").
  ///
  /// Retorna `true` únicamente si:
  /// 1. Se configuró `SHOW_TECHNICAL_INFO=true` como variable de entorno, o
  /// 2. El entorno actual es `dev`, `development` o `test`.
  /// En producción (`prod`), retorna `false` por defecto.
  static bool get showTechnicalInfo {
    if (_overrideShowTechnicalInfo != null) {
      return _overrideShowTechnicalInfo!;
    }
    if (_envShowTechnicalInfo) {
      return true;
    }
    final env = environment.toLowerCase().trim();
    return env == 'dev' || env == 'test' || env == 'development' || env == 'qa';
  }

  /// Formatea el subtítulo de cualquier vista de la aplicación de acuerdo al entorno.
  ///
  /// - Si [showTechnicalInfo] es `true` (dev/test):
  ///   Retorna `"Hoja $sheetName • $userFriendlyText"`.
  /// - Si [showTechnicalInfo] es `false` (producción):
  ///   Retorna únicamente `"$userFriendlyText"`.
  static String formatSubtitle({
    required String sheetName,
    required String userFriendlyText,
  }) {
    if (showTechnicalInfo) {
      return 'Hoja $sheetName • $userFriendlyText';
    }
    return userFriendlyText;
  }
}
