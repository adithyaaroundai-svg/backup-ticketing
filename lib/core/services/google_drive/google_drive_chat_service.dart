import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/storage_utils.dart';
import 'google_drive_models.dart';
import 'google_drive_auth.dart';

/// Custom HTTP Client that injects an Authorization Bearer token into outgoing requests.
class _BearerAuthClient extends http.BaseClient {
  final String _token;
  final http.Client _client = http.Client();

  _BearerAuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _client.send(request);
  }
}

/// Service that coordinates automated company-wide Google Drive uploads for large chat attachments (> 45 MB).
///
/// Designed with Option 1 / Choice A:
/// An admin conducts a one-time authorization of the company Google Drive account.
/// All team members and agents automatically share and stream files directly to that company Google Drive
/// without individual sign-in popups, generating instant shareable links in chat (Gmail style).
class GoogleDriveChatService {
  static const String settingKey = 'company_google_drive';
  static const String _prefKey = 'company_google_drive_cached_config';

  static GoogleDriveConfig? _cachedConfig;
  static DateTime? _lastFetchTime;

  static SupabaseClient get _supabase => Supabase.instance.client;

  /// Returns whether the company Google Drive is connected and ready to accept uploads.
  static Future<bool> isConfigured() async {
    final config = await getConfig();
    return config != null && config.connected && config.canAuthenticate;
  }

  /// Retrieves the current Google Drive configuration from cache, Supabase app_settings, or local preferences.
  static Future<GoogleDriveConfig?> getConfig({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedConfig != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
      return _cachedConfig;
    }

    // 1. Try reading from Supabase app_settings table
    try {
      final res = await _supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', settingKey)
          .maybeSingle();

      if (res != null && res['setting_value'] != null) {
        final val = res['setting_value'];
        final Map<String, dynamic> map =
            val is Map<String, dynamic> ? val : (val is String ? jsonDecode(val) : {});
        if (map.isNotEmpty) {
          _cachedConfig = GoogleDriveConfig.fromJson(map);
          _lastFetchTime = DateTime.now();
          await _saveToLocalCache(_cachedConfig!);
          return _cachedConfig;
        }
      }
    } catch (e) {
      debugPrint('[GoogleDrive] Warning reading app_settings: $e');
    }

    // 2. Fall back to local cached preferences
    final localConfig = await _loadFromLocalCache();
    if (localConfig != null) {
      _cachedConfig = localConfig;
      _lastFetchTime = DateTime.now();
      return _cachedConfig;
    }

    return null;
  }

  /// Saves the Google Drive configuration to Supabase app_settings and local preferences.
  static Future<void> saveConfig(GoogleDriveConfig config) async {
    _cachedConfig = config;
    _lastFetchTime = DateTime.now();
    await _saveToLocalCache(config);

    try {
      await _supabase.from('app_settings').upsert({
        'setting_key': settingKey,
        'setting_value': config.toJson(),
      });
      debugPrint('[GoogleDrive] Configuration synced to Supabase app_settings.');
    } catch (e) {
      debugPrint('[GoogleDrive] Error saving to Supabase app_settings: $e');
    }
  }

  /// Disconnects the company Google Drive integration.
  static Future<void> disconnect() async {
    _cachedConfig = null;
    _lastFetchTime = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}

    try {
      await _supabase
          .from('app_settings')
          .delete()
          .eq('setting_key', settingKey);
      debugPrint('[GoogleDrive] Disconnected and removed from app_settings.');
    } catch (e) {
      debugPrint('[GoogleDrive] Error removing from app_settings: $e');
    }
  }

  /// Refreshes the OAuth access token using the stored refresh token via universal standard HTTP POST.
  /// Works across all platforms without platform-specific dependencies.
  static Future<String> _ensureValidAccessToken(GoogleDriveConfig config) async {
    if (config.isTokenValid && config.accessToken != null) {
      return config.accessToken!;
    }

    if (config.refreshToken == null || config.refreshToken!.isEmpty) {
      if (config.accessToken != null && config.accessToken!.isNotEmpty) {
        return config.accessToken!;
      }
      throw Exception('Google Drive authorization missing refresh token. Please re-authorize.');
    }

    debugPrint('[GoogleDrive] Refreshing access token via oauth2 token endpoint...');
    final response = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': config.clientId,
        if (config.clientSecret != null && config.clientSecret!.isNotEmpty)
          'client_secret': config.clientSecret,
        'refresh_token': config.refreshToken!,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccessToken = data['access_token'] as String;
      final expiresIn = (data['expires_in'] as int?) ?? 3600;
      final newExpiry = DateTime.now().add(Duration(seconds: expiresIn));

      final updatedConfig = config.copyWith(
        accessToken: newAccessToken,
        expiry: newExpiry,
      );

      // Persist updated token
      await saveConfig(updatedConfig);
      debugPrint('[GoogleDrive] Successfully refreshed access token (valid until $newExpiry).');
      return newAccessToken;
    } else {
      debugPrint('[GoogleDrive] Token refresh failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to refresh Google Drive token: ${response.body}');
    }
  }

  /// Returns an authenticated HTTP client for Google Drive API calls.
  static Future<http.Client> getAuthenticatedClient() async {
    final config = await getConfig();
    if (config == null || !config.connected) {
      throw Exception('Company Google Drive is not connected.');
    }

    final accessToken = await _ensureValidAccessToken(config);
    return _BearerAuthClient(accessToken);
  }

  /// Conducts one-time admin authorization of the company Google Drive account.
  static Future<GoogleDriveConfig> authorizeCompanyAccount({
    String? customClientId,
    String? customClientSecret,
    String? customFolderName,
  }) async {
    final clientId = (customClientId != null && customClientId.trim().isNotEmpty)
        ? customClientId.trim()
        : GoogleDriveConfig.defaultClientId;
    final clientSecret = customClientSecret?.trim();
    final folderName = (customFolderName != null && customFolderName.trim().isNotEmpty)
        ? customFolderName.trim()
        : GoogleDriveConfig.defaultFolderName;

    final scopes = [
      drive.DriveApi.driveFileScope,
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ];

    debugPrint('[GoogleDrive] Starting OAuth consent flow for clientId: $clientId...');
    final authResult = await performUserConsentAuth(
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: scopes,
    );

    if (authResult == null) {
      throw Exception('Google Drive authorization was cancelled by user.');
    }

    // Build temporary config to verify access and create target folder
    var config = GoogleDriveConfig(
      connected: true,
      email: authResult.email,
      folderName: folderName,
      clientId: clientId,
      clientSecret: clientSecret,
      refreshToken: authResult.refreshToken,
      accessToken: authResult.accessToken,
      expiry: authResult.expiry,
      connectedAt: DateTime.now().toUtc(),
      connectedBy: 'admin',
    );

    // Ensure access token is valid and create the dedicated attachments folder
    final token = await _ensureValidAccessToken(config);
    final driveApi = drive.DriveApi(_BearerAuthClient(token));
    final folderId = await _findOrCreateFolder(driveApi, folderName);

    config = config.copyWith(folderId: folderId);
    await saveConfig(config);

    debugPrint('[GoogleDrive] Successfully connected account "${config.email}" to folder "$folderName" ($folderId).');
    return config;
  }

  /// Connects the company Google Drive using a pre-generated OAuth Refresh Token.
  /// Bypasses browser popup and origin_mismatch restrictions on local/development environments.
  static Future<GoogleDriveConfig> connectWithRefreshToken({
    required String refreshToken,
    String? clientId,
    String? clientSecret,
    String? folderName,
    String? email,
  }) async {
    final effectiveClientId = (clientId != null && clientId.trim().isNotEmpty)
        ? clientId.trim()
        : GoogleDriveConfig.defaultClientId;
    final effectiveFolder = (folderName != null && folderName.trim().isNotEmpty)
        ? folderName.trim()
        : GoogleDriveConfig.defaultFolderName;

    var config = GoogleDriveConfig(
      connected: true,
      email: email,
      folderName: effectiveFolder,
      clientId: effectiveClientId,
      clientSecret: clientSecret?.trim(),
      refreshToken: refreshToken.trim(),
      connectedAt: DateTime.now().toUtc(),
      connectedBy: 'admin',
    );

    // Verify token by refreshing it via Google token endpoint
    debugPrint('[GoogleDrive] Validating provided refresh token...');
    final token = await _ensureValidAccessToken(config);
    final driveApi = drive.DriveApi(_BearerAuthClient(token));

    // Auto-detect authorized email if not explicitly provided
    String? detectedEmail = email;
    try {
      final about = await driveApi.about.get($fields: 'user(displayName, emailAddress)');
      detectedEmail ??= about.user?.emailAddress;
      debugPrint('[GoogleDrive] Verified Google account: $detectedEmail');
    } catch (e) {
      debugPrint('[GoogleDrive] Notice getting profile: $e');
    }

    // Ensure attachments folder exists in this account's Drive
    final folderId = await _findOrCreateFolder(driveApi, effectiveFolder);

    config = config.copyWith(
      email: detectedEmail ?? 'Company Google Drive',
      folderId: folderId,
    );

    await saveConfig(config);
    debugPrint('[GoogleDrive] Successfully connected with refresh token to folder "$effectiveFolder" ($folderId).');
    return config;
  }

  /// Uploads a large chat attachment directly to Google Drive.
  ///
  /// Streams directly from disk with minimal RAM footprint (< 10 MB) even for multi-gigabyte files.
  /// Automatically sets view permissions ("anyone with the link can view") and returns the shareable link.
  static Future<GoogleDriveUploadResult> uploadLargeFile({
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final config = await getConfig();
    if (config == null || !config.connected) {
      throw Exception(
        'Company Google Drive is not connected. Please connect Google Drive in Settings -> Integrations to enable uploads over 45 MB.',
      );
    }

    final token = await _ensureValidAccessToken(config);
    final driveApi = drive.DriveApi(_BearerAuthClient(token));

    // 1. Ensure target folder exists
    String? folderId = config.folderId;
    if (folderId == null || folderId.isEmpty) {
      folderId = await _findOrCreateFolder(driveApi, config.folderName);
      if (folderId != null) {
        await saveConfig(config.copyWith(folderId: folderId));
      }
    }

    // 2. Resolve file size and prepare stream
    final totalSize = file.size > 0
        ? file.size
        : (!kIsWeb && file.path != null && File(file.path!).existsSync()
            ? File(file.path!).lengthSync()
            : (file.bytes?.length ?? 0));

    if (totalSize <= 0) {
      throw Exception('Cannot upload empty or unreadable file "${file.name}".');
    }

    final mimeType = getMimeType(file.extension, file.name);
    drive.Media media;

    if (!kIsWeb && file.path != null && File(file.path!).existsSync()) {
      final fileObj = File(file.path!);
      int bytesSent = 0;
      final progressStream = fileObj.openRead().transform<List<int>>(
        StreamTransformer.fromHandlers(
          handleData: (chunk, sink) {
            bytesSent += chunk.length;
            if (totalSize > 0 && onProgress != null) {
              final ratio = (bytesSent / totalSize).clamp(0.0, 1.0);
              onProgress(ratio);
            }
            sink.add(chunk);
          },
        ),
      );
      media = drive.Media(progressStream, totalSize, contentType: mimeType);
    } else if (file.bytes != null && file.bytes!.isNotEmpty) {
      final rawBytes = file.bytes!;
      const chunkSize = 256 * 1024; // 256 KB chunk for granular progress updates
      int bytesSent = 0;

      Stream<List<int>> byteStream() async* {
        for (int i = 0; i < rawBytes.length; i += chunkSize) {
          final end = (i + chunkSize < rawBytes.length) ? i + chunkSize : rawBytes.length;
          final chunk = rawBytes.sublist(i, end);
          bytesSent += chunk.length;
          if (onProgress != null && rawBytes.isNotEmpty) {
            final ratio = (bytesSent / rawBytes.length).clamp(0.0, 1.0);
            onProgress(ratio);
          }
          yield chunk;
          // Yield to Flutter event loop so UI repaints the progress bar
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      media = drive.Media(byteStream(), rawBytes.length, contentType: mimeType);
    } else {
      throw Exception('Cannot read file content for "${file.name}".');
    }

    debugPrint('[GoogleDrive] Streaming "${file.name}" (${formatChatFileSize(totalSize)}) to Google Drive...');

    // 3. Create the file in Google Drive
    final driveFile = drive.File()
      ..name = file.name
      ..parents = folderId != null ? [folderId] : null
      ..description = 'TallyCare Large Chat Attachment (${formatChatFileSize(totalSize)})';

    final uploaded = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id, name, webViewLink, webContentLink, size',
    );

    final fileId = uploaded.id;
    if (fileId == null || fileId.isEmpty) {
      throw Exception('Failed to receive file ID from Google Drive.');
    }

    debugPrint('[GoogleDrive] File uploaded successfully with ID: $fileId');

    // 4. Set share permission to "anyone with the link can view"
    try {
      final permission = drive.Permission()
        ..role = 'reader'
        ..type = 'anyone';

      await driveApi.permissions.create(
        permission,
        fileId,
        $fields: 'id',
      );
      debugPrint('[GoogleDrive] Set public view permission on file $fileId.');
    } catch (e) {
      debugPrint('[GoogleDrive] Permission notice (may be restricted by Workspace domain policy): $e');
    }

    // 5. Build shareable link
    final shareUrl = uploaded.webViewLink ??
        'https://drive.google.com/file/d/$fileId/view?usp=sharing';

    onProgress?.call(1.0);

    return GoogleDriveUploadResult(
      fileId: fileId,
      fileName: file.name,
      fileUrl: shareUrl,
      fileSize: totalSize,
    );
  }

  /// Tests the connection to Google Drive by verifying token refresh and folder accessibility.
  static Future<bool> testConnection() async {
    try {
      final config = await getConfig(forceRefresh: true);
      if (config == null || !config.connected) return false;

      final token = await _ensureValidAccessToken(config);
      final driveApi = drive.DriveApi(_BearerAuthClient(token));

      final about = await driveApi.about.get($fields: 'user(displayName, emailAddress)');
      debugPrint('[GoogleDrive] Test connection success: ${about.user?.emailAddress}');
      return true;
    } catch (e) {
      debugPrint('[GoogleDrive] Test connection failed: $e');
      return false;
    }
  }

  static Future<String?> _findOrCreateFolder(drive.DriveApi driveApi, String folderName) async {
    try {
      final query =
          "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
      final searchResult = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        final id = searchResult.files!.first.id;
        if (id != null && id.isNotEmpty) {
          debugPrint('[GoogleDrive] Found existing folder "$folderName" ($id)');
          return id;
        }
      }

      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(
        folderMetadata,
        $fields: 'id, name',
      );
      debugPrint('[GoogleDrive] Created folder "$folderName" (${createdFolder.id})');
      return createdFolder.id;
    } catch (e) {
      debugPrint('[GoogleDrive] Error finding/creating folder: $e');
      return null;
    }
  }

  static Future<void> _saveToLocalCache(GoogleDriveConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, config.serialize());
    } catch (_) {}
  }

  static Future<GoogleDriveConfig?> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      return GoogleDriveConfig.deserialize(raw);
    } catch (_) {
      return null;
    }
  }
}

