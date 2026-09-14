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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await tokenStorage.clearToken();
  }
}
