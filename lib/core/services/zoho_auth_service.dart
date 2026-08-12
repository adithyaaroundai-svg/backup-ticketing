import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ZohoAuthService {
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Retrieves a valid access token. If the current token is missing or expired,
  /// it uses the refresh token to get a new one from Zoho.
  static Future<String> getAccessToken() async {
    // If we have a token and it hasn't expired (adding 5 minute buffer), return it
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().add(const Duration(minutes: 5)).isBefore(_tokenExpiry!)) {
        return _accessToken!;
      }
    }

    final clientId = dotenv.env['ZOHO_CLIENT_ID'];
    final clientSecret = dotenv.env['ZOHO_CLIENT_SECRET'];
    final refreshToken = dotenv.env['ZOHO_REFRESH_TOKEN'];

    if (clientId == null || clientSecret == null || refreshToken == null) {
      throw Exception('Zoho credentials are not properly configured in .env file.');
    }

    // Using .in because your account is on the India data center
    String urlString = 'https://accounts.zoho.in/oauth/v2/token';
    if (kIsWeb) {
      urlString = 'https://corsproxy.io/?url=${Uri.encodeComponent(urlString)}';
    }
    final url = Uri.parse(urlString);
    
    final response = await http.post(
      url,
      body: {
        'refresh_token': refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['access_token'] != null) {
        _accessToken = data['access_token'];
        // Zoho tokens usually expire in 3600 seconds (1 hour)
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        return _accessToken!;
      } else {
        throw Exception('Failed to get access token: ${response.body}');
      }
    } else {
      throw Exception('HTTP error generating Zoho token: ${response.statusCode}\n${response.body}');
    }
  }
}
