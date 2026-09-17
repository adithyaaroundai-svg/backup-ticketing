import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _GoogleAuthHeadersClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthHeadersClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveBackupResult {
  final bool success;
  final String? fileId;
  final String? fileName;
  final String? folderId;
  final String? error;

  const GoogleDriveBackupResult.success({
    required this.fileId,
    required this.fileName,
    this.folderId,
  })  : success = true,
        error = null;

  const GoogleDriveBackupResult.failure(this.error)
      : success = false,
        fileId = null,
        fileName = null,
        folderId = null;
}

class GoogleDriveBackupService {
  static const String clientId = '612593817412-nonsif4brt3dn3mvebtthk41klhgf92l.apps.googleusercontent.com';
  static const String targetFolderName = 'TallyCare Backups';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? clientId : null,
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  /// Prompts user to sign into Google (or re-uses session) and uploads zip backup to Google Drive.
  static Future<GoogleDriveBackupResult> uploadZipToDrive({
    required List<int> zipBytes,
    required String fileName,
  }) async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      account ??= await _googleSignIn.signIn();

      if (account == null) {
        return const GoogleDriveBackupResult.failure('Google Sign-In was cancelled.');
      }

      // Check and request Drive file scope if not granted
      final hasScope = await _googleSignIn.canAccessScopes([drive.DriveApi.driveFileScope]);
      if (!hasScope) {
        final granted = await _googleSignIn.requestScopes([drive.DriveApi.driveFileScope]);
        if (!granted) {
          return const GoogleDriveBackupResult.failure('Google Drive permission was denied.');
        }
      }

      // Build authenticated HTTP client directly using account authHeaders
      // (Bypasses People API requirement)
      final authHeaders = await account.authHeaders;
      final authClient = _GoogleAuthHeadersClient(authHeaders);

      return await _performUpload(drive.DriveApi(authClient), zipBytes, fileName);
    } catch (e) {
      return GoogleDriveBackupResult.failure(e.toString());
    }
  }

  static Future<GoogleDriveBackupResult> _performUpload(
    drive.DriveApi driveApi,
    List<int> zipBytes,
    String fileName,
  ) async {
    // 1. Find or create the "TallyCare Backups" folder
    String? folderId = await _findOrCreateFolder(driveApi, targetFolderName);

    // 2. Upload file into the folder
    final driveFile = drive.File()
      ..name = fileName
      ..parents = folderId != null ? [folderId] : null
      ..description = 'TallyCare Automated CRM Database Backup';

    final media = drive.Media(
      Stream.value(zipBytes),
      zipBytes.length,
      contentType: 'application/zip',
    );

    final uploaded = await driveApi.files.create(
      driveFile,
      uploadMedia: media,
      $fields: 'id, name, parents',
    );

    debugPrint('Uploaded file ${uploaded.name} (id: ${uploaded.id}) into folder: $folderId');

    return GoogleDriveBackupResult.success(
      fileId: uploaded.id,
      fileName: fileName,
      folderId: folderId,
    );
  }

  static Future<String?> _findOrCreateFolder(drive.DriveApi driveApi, String folderName) async {
    try {
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
      final searchResult = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      
      if (searchResult.files != null && searchResult.files!.isNotEmpty) {
        final id = searchResult.files!.first.id;
        if (id != null && id.isNotEmpty) {
          debugPrint('Found existing folder $folderName with id: $id');
          return id;
        }
      }

      // Create folder if not found
      final folderMetadata = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(
        folderMetadata,
        $fields: 'id, name',
      );
      debugPrint('Created new folder $folderName with id: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error finding/creating folder: $e');
      return null;
    }
  }
}
