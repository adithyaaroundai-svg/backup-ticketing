import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:url_launcher/url_launcher.dart';
import 'google_drive_auth_models.dart';

Future<GoogleAuthResult?> performUserConsentAuth({
  required String clientId,
  String? clientSecret,
  required List<String> scopes,
}) async {
  try {
    final authClientId = auth_io.ClientId(clientId, clientSecret);
    final client = await auth_io.clientViaUserConsent(
      authClientId,
      scopes,
      (url) async {
        debugPrint('Google Drive OAuth launch URL: $url');
        final uri = Uri.parse(url);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          debugPrint('Failed to launch URL in external application: $url');
        }
      },
    );

    final credentials = client.credentials;
    final refreshToken = credentials.refreshToken;
    final accessToken = credentials.accessToken.data;
    final expiry = credentials.accessToken.expiry;

    // Fetch user profile to get email
    String? email;
    String? displayName;
    try {
      final res = await client.get(Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        email = data['email']?.toString();
        displayName = data['name']?.toString();
      }
    } catch (e) {
      debugPrint('Failed to fetch userinfo: $e');
    }

    client.close();

    return GoogleAuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiry: expiry,
      email: email,
      displayName: displayName,
    );
  } catch (e) {
    debugPrint('Google Drive auth IO error: $e');
    rethrow;
  }
}

