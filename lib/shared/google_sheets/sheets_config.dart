class SheetsConfig {
  static const String _envSpreadsheetId = String.fromEnvironment(
    'SPREADSHEET_ID',
    defaultValue: '1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI',
  );

  /// Extrae de forma segura el ID de la hoja de cálculo tanto si el usuario
  /// ingresa la URL completa de Google Sheets como si ingresa sólo el ID.
  static String extractSpreadsheetId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI';
    final regExp = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return trimmed;
  }

  static String get defaultSpreadsheetId => extractSpreadsheetId(_envSpreadsheetId);

  /// Sin `--dart-define-from-file`, la app usa la implementación de
  /// PRODUCCIÓN, la misma que actualiza tools/apps_script/deploy.sh (antes
  /// apuntaba a una implementación vieja, sin las reglas actuales).
  static const String _envAppsScriptUrl = String.fromEnvironment(
    'APPS_SCRIPT_URL',
    defaultValue: 'https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec',
  );

  static String get defaultAppsScriptUrl => _envAppsScriptUrl;

  /// Permisos de Google que pide el login: solo el email (lo verifica el
  /// Apps Script con el token de acceso). La app no usa la API de Sheets ni
  /// de Drive con la cuenta del usuario: pedir esos permisos daba acceso a
  /// TODAS sus hojas y a leer todo su Drive con un token guardado en el
  /// teléfono.
  static const List<String> scopes = ['email'];
}

