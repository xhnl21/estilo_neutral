import '../storage/secure_token_storage.dart';

class SheetsClient {
  final SecureTokenStorage tokenStorage;
  final String spreadsheetId;

  SheetsClient({required this.tokenStorage, required this.spreadsheetId});

  // Métodos wrapper para interactuar con Google Sheets API bajo demanda
  Future<bool> isConnected() async {
    final token = await tokenStorage.getToken();
    return token != null && token.isNotEmpty;
  }
}
