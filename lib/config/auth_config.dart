import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Configuración de Autenticación Segura OAuth 2.0 para Google Sheets
/// Cumplimiento estricto: OWASP MASVS / ISO/IEC 27001 §9.2
class AuthConfig {
  /// Scopes estrictamente mínimos necesarios:
  /// - spreadsheets: Lectura y escritura de datos de la hoja
  /// - drive.readonly: Acceso de solo lectura a metadatos y fotos de Google Drive
  static const List<String> requiredScopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.readonly',
  ];

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: requiredScopes,
  );

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _tokenKey = 'auth_token_estilo_neutral';

  /// Inicia sesión con Google de forma interactiva
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          await _secureStorage.write(key: _tokenKey, value: auth.accessToken);
        }
      }
      return account;
    } catch (e) {
      // Manejo de excepciones sin exponer credenciales
      rethrow;
    }
  }

  /// Recupera el token almacenado de forma segura
  static Future<String?> getStoredToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  /// Intenta inicio de sesión silencioso (refresh de sesión)
  static Future<GoogleSignInAccount?> signInSilently() async {
    return await _googleSignIn.signInSilently();
  }

  /// Cierra la sesión y limpia el almacenamiento seguro
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _secureStorage.delete(key: _tokenKey);
  }

  /// Verifica si el usuario actual está autenticado
  static bool get isAuthenticated => _googleSignIn.currentUser != null;

  /// Cuenta autenticada actualmente
  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
