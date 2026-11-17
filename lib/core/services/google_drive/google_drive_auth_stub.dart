import 'google_drive_auth_models.dart';

Future<GoogleAuthResult?> performUserConsentAuth({
  required String clientId,
  String? clientSecret,
  required List<String> scopes,
}) async {
  throw UnsupportedError('Google Drive authorization is not supported on this platform.');
}

