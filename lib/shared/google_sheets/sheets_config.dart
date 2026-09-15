class SheetsConfig {
  static const String _envSpreadsheetId = String.fromEnvironment(
    'SPREADSHEET_ID',
    defaultValue: '1zJWnxXk3QSG-keyOHMEOrfY72cmtLUdv',
  );

  /// Extrae de forma segura el ID de la hoja de cálculo tanto si el usuario
  /// ingresa la URL completa de Google Sheets como si ingresa sólo el ID.
  static String extractSpreadsheetId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '1zJWnxXk3QSG-keyOHMEOrfY72cmtLUdv';
    final regExp = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return trimmed;
  }

  static String get defaultSpreadsheetId => extractSpreadsheetId(_envSpreadsheetId);

  static const String _envAppsScriptUrl = String.fromEnvironment(
    'APPS_SCRIPT_URL',
    defaultValue: '',
  );

  static String get defaultAppsScriptUrl => _envAppsScriptUrl;

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.readonly',
  ];
}

