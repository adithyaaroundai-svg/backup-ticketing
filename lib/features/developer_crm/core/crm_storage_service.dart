import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'upload_part.dart';

class CrmStorageService {
  static const String primaryBucket = 'chat_attachments';

  /// Ensures that Supabase client has a valid authenticated session
  /// so that storage RLS upload policies are satisfied.
  static Future<void> ensureAuth() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInWithPassword(
          email: 'agents@tallycare.local',
          password: 'AgentShared#2026',
        );
      } catch (e) {
        debugPrint('[CrmStorage] Auto-auth error: $e');
      }
    }
  }

  /// Resolves the MIME type for common uploaded files, especially ZIP archives.
  static String getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'zip':
      case '7z':
      case 'rar':
      case 'tar':
      case 'gz':
        return 'application/zip';
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
      case 'xls':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'tcp':
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }

  /// Uploads a file part to Supabase storage.
  /// On native platforms (Windows, macOS, Linux, Android, iOS), streams the file
  /// directly from disk using File(path), so files of ANY size (e.g. 100MB+, 500MB+ ZIPs)
  /// upload reliably without memory exhaustion or RAM crashes.
  /// On Web, uploads the binary bytes.
  static Future<String> uploadFile(UploadPart part) async {
    await ensureAuth();
    final supabase = Supabase.instance.client;

    // Sanitize filename for storage path
    final cleanName = part.filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'crm_files/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final mime = getMimeType(part.filename);

    if (!kIsWeb && part.filePath != null && part.filePath!.isNotEmpty) {
      final file = File(part.filePath!);
      if (await file.exists()) {
        await supabase.storage.from(primaryBucket).upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: mime,
            upsert: true,
          ),
        );
        return storagePath;
      }
    }

    // Web or bytes fallback
    List<int> bytes = part.bytes;
    if (bytes.isEmpty && !kIsWeb && part.filePath != null) {
      final file = File(part.filePath!);
      if (await file.exists()) {
        bytes = await file.readAsBytes();
      }
    }

    if (bytes.isEmpty) {
      throw Exception('Cannot upload empty file "${part.filename}". Please select a valid file.');
    }

    await supabase.storage.from(primaryBucket).uploadBinary(
      storagePath,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(
        contentType: mime,
        upsert: true,
      ),
    );
    return storagePath;
  }

  /// Constructs a full download URL for the stored file.
  /// Appends `?download=<filename>` so the browser triggers a file save dialog
  /// with the original file name rather than attempting to render it inline.
  static String getDownloadUrl(String storagePath, {String? filename}) {
    if (storagePath.isEmpty) return '';

    if (storagePath.startsWith('http://') || storagePath.startsWith('https://')) {
      final uri = Uri.parse(storagePath);
      if (filename != null && filename.isNotEmpty && !uri.queryParameters.containsKey('download')) {
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['download'] = filename;
        return uri.replace(queryParameters: newParams).toString();
      }
      return storagePath;
    }

    final supabase = Supabase.instance.client;
    final String bucket;
    final String path;

    if (storagePath.startsWith('crm_files/')) {
      bucket = primaryBucket;
      path = storagePath;
    } else if (storagePath.startsWith('chat_attachments/')) {
      bucket = primaryBucket;
      path = storagePath.substring('chat_attachments/'.length);
    } else if (storagePath.startsWith('dev_crm_files/')) {
      bucket = 'dev_crm_files';
      path = storagePath.substring('dev_crm_files/'.length);
    } else {
      bucket = primaryBucket;
      path = storagePath;
    }

    String publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
    final fn = filename ?? (path.contains('/') ? path.split('/').last : path);
    if (fn.isNotEmpty) {
      final separator = publicUrl.contains('?') ? '&' : '?';
      publicUrl = '$publicUrl${separator}download=${Uri.encodeComponent(fn)}';
    }
    return publicUrl;
  }
}
