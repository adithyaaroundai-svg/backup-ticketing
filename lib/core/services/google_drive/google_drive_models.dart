import 'dart:convert';

/// Configuration for company-wide Google Drive integration for chat attachments.
class GoogleDriveConfig {
  final bool connected;
  final String? email;
  final String folderName;
  final String? folderId;
  final String clientId;
  final String? clientSecret;
  final String? refreshToken;
  final String? accessToken;
  final DateTime? expiry;
  final int thresholdBytes;
  final DateTime? connectedAt;
  final String? connectedBy;

  static const String defaultClientId =
      '612593817412-nonsif4brt3dn3mvebtthk41klhgf92l.apps.googleusercontent.com';
  static const String defaultFolderName = 'TallyCare Chat Attachments';
  static const int defaultThresholdBytes = 45 * 1024 * 1024; // 45 MB

  const GoogleDriveConfig({
    required this.connected,
    this.email,
    this.folderName = defaultFolderName,
    this.folderId,
    this.clientId = defaultClientId,
    this.clientSecret,
    this.refreshToken,
    this.accessToken,
    this.expiry,
    this.thresholdBytes = defaultThresholdBytes,
    this.connectedAt,
    this.connectedBy,
  });

  bool get isTokenValid {
    if (accessToken == null || accessToken!.isEmpty) return false;
    if (expiry == null) return false;
    return expiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  bool get canAuthenticate {
    if (!connected) return false;
    if (refreshToken != null && refreshToken!.trim().isNotEmpty) return true;
    return accessToken != null && accessToken!.trim().isNotEmpty && isTokenValid;
  }

  GoogleDriveConfig copyWith({
    bool? connected,
    String? email,
    String? folderName,
    String? folderId,
    String? clientId,
    String? clientSecret,
    String? refreshToken,
    String? accessToken,
    DateTime? expiry,
    int? thresholdBytes,
    DateTime? connectedAt,
    String? connectedBy,
  }) {
    return GoogleDriveConfig(
      connected: connected ?? this.connected,
      email: email ?? this.email,
      folderName: folderName ?? this.folderName,
      folderId: folderId ?? this.folderId,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken,
      expiry: expiry ?? this.expiry,
      thresholdBytes: thresholdBytes ?? this.thresholdBytes,
      connectedAt: connectedAt ?? this.connectedAt,
      connectedBy: connectedBy ?? this.connectedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connected': connected,
      'email': email,
      'folder_name': folderName,
      'folder_id': folderId,
      'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'access_token': accessToken,
      'expiry': expiry?.toIso8601String(),
      'threshold_bytes': thresholdBytes,
      'connected_at': connectedAt?.toIso8601String(),
      'connected_by': connectedBy,
    };
  }

  factory GoogleDriveConfig.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return GoogleDriveConfig(
      connected: json['connected'] == true,
      email: json['email']?.toString(),
      folderName: json['folder_name']?.toString() ?? defaultFolderName,
      folderId: json['folder_id']?.toString(),
      clientId: json['client_id']?.toString() ?? defaultClientId,
      clientSecret: json['client_secret']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
      accessToken: json['access_token']?.toString(),
      expiry: parseDate(json['expiry']),
      thresholdBytes: json['threshold_bytes'] is int
          ? json['threshold_bytes'] as int
          : (int.tryParse(json['threshold_bytes']?.toString() ?? '') ?? defaultThresholdBytes),
      connectedAt: parseDate(json['connected_at']),
      connectedBy: json['connected_by']?.toString(),
    );
  }

  String serialize() => jsonEncode(toJson());

  static GoogleDriveConfig? deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return GoogleDriveConfig.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

/// Result of uploading a large chat attachment to Google Drive.
class GoogleDriveUploadResult {
  final String fileId;
  final String fileName;
  final String fileUrl;
  final int fileSize;

  const GoogleDriveUploadResult({
    required this.fileId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
  });
}

