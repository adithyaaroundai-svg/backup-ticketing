import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_drive_auth_models.dart';

Future<GoogleAuthResult?> performUserConsentAuth({
  required String clientId,
  String? clientSecret,
  required List<String> scopes,
}) async {
  try {
    final googleSignIn = GoogleSignIn(
      clientId: clientId,
      scopes: scopes,
    );

    GoogleSignInAccount? account = googleSignIn.currentUser;
    account ??= await googleSignIn.signInSilently();
    account ??= await googleSignIn.signIn();

    if (account == null) {
      return null;
    }

    final hasScope = await googleSignIn.canAccessScopes(scopes);
    if (!hasScope) {
      final granted = await googleSignIn.requestScopes(scopes);
      if (!granted) {
        throw Exception('Google Drive permissions were denied.');
      }
    }

    final auth = await account.authentication;

    return GoogleAuthResult(
      accessToken: auth.accessToken,
      refreshToken: null, // Web client uses session tokens
      expiry: DateTime.now().add(const Duration(hours: 1)),
      email: account.email,
      displayName: account.displayName,
    );
  } catch (e) {
    debugPrint('Google Drive auth Web error: $e');
    rethrow;
  }
}

