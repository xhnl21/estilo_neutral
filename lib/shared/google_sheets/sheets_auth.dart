import 'package:google_sign_in/google_sign_in.dart';
import '../storage/secure_token_storage.dart';
import 'sheets_config.dart';

class SheetsAuth {
  final SecureTokenStorage tokenStorage;
  final GoogleSignIn _googleSignIn;

  SheetsAuth({required this.tokenStorage})
      : _googleSignIn = GoogleSignIn(scopes: SheetsConfig.scopes);

  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account != null) {
      final auth = await account.authentication;
      if (auth.accessToken != null) {
        await tokenStorage.saveToken(auth.accessToken!);
      }
    }
    return account;
  }

  /// Intenta restaurar la última sesión de Google sin mostrar el selector de
  /// cuentas. Devuelve `null` si no hay una sesión previa válida (primera vez,
  /// o el usuario cerró sesión explícitamente).
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          await tokenStorage.saveToken(auth.accessToken!);
        }
      }
      return account;
    } catch (_) {
      return null;
    }
  }

  /// Token de acceso vigente de la sesión de Google abierta (Google lo
  /// renueva si venció), o `null` si no hay sesión. No abre ninguna sesión:
  /// después de cerrar sesión devuelve `null`.
  Future<String?> tokenDeAcceso() async {
    final cuenta = _googleSignIn.currentUser;
    if (cuenta == null) return null;
    try {
      return (await cuenta.authentication).accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await tokenStorage.clearToken();
  }
}
