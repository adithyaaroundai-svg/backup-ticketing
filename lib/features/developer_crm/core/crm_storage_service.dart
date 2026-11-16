import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crm_file_reader.dart';
import 'upload_part.dart';

/// Progress callback for multi-file batch uploads.
typedef CrmBatchUploadProgress = void Function(
  int currentIndex,
  int totalCount,
  double fileProgress,
  String filename,
);

/// Actionable storage error surfaced cleanly in CRM dialogs and snackbars.
class CrmStorageException implements Exception {
  final String message;
  final int? statusCode;

  CrmStorageException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

enum DownloadAvailabilityStatus { available, missing, unverifiable }

class DownloadCheckResult {
  final DownloadAvailabilityStatus status;
  final int? statusCode;
  final bool isLegacyPath;

  const DownloadCheckResult({
    required this.status,
    this.statusCode,
    this.isLegacyPath = false,
  });
}

class CrmStorageService {
  static const String primaryBucket = 'chat_attachments';
  static const int currentKnownMaxUploadBytes = 50 * 1024 * 1024;
  static const int tusThresholdBytes = 6 * 1024 * 1024;
  static const int tusChunkSizeBytes = 6 * 1024 * 1024;

  static int _uploadSeq = 0;

  /// Ensures Supabase has a non-expired authenticated session for Storage RLS.
  static Future<void> ensureAuth() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session != null && !session.isExpired) return;

    if (session != null && session.isExpired) {
      try {
        await client.auth.refreshSession();
        if (client.auth.currentSession != null &&
            !client.auth.currentSession!.isExpired) {
          return;
        }
      } catch (e) {
        debugPrint('[CrmStorage] Session refresh failed: $e');
      }
    }

    try {
      await client.auth.signInWithPassword(
        email: 'agents@tallycare.local',
        password: 'AgentShared#2026',
      );
    } catch (e) {
      debugPrint('[CrmStorage] Auto-auth error: $e');
      throw CrmStorageException(
        'Could not authenticate for file transfer: $e',
      );
    }

    if (client.auth.currentSession == null) {
      throw CrmStorageException('No active authenticated storage session.');
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Resolves the MIME type from the filename extension.
  static String getMimeType(String filename) {
    final dotIdx = filename.lastIndexOf('.');
    if (dotIdx < 0 || dotIdx == filename.length - 1) {
      return 'application/octet-stream';
    }
    final ext = filename.substring(dotIdx + 1).toLowerCase();
    switch (ext) {
      case 'zip':
      case '7z':
      case 'rar':
      case 'tar':
      case 'gz':
        return 'application/zip';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'txt':
      case 'log':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'mp4':
        return 'video/mp4';
      case 'tcp':
      case 'tdl':
      default:
        return 'application/octet-stream';
    }
  }

  static String sanitizeFileName(String filename) {
    final trimmed = filename.trim();
    if (trimmed.isEmpty) return 'attachment';
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static String buildStoragePath(String filename) {
    _uploadSeq = (_uploadSeq + 1) % 100000;
    final cleanName = sanitizeFileName(filename);
    return 'crm_files/${DateTime.now().millisecondsSinceEpoch}_${_uploadSeq}_$cleanName';
  }

  /// True for legacy migrated `task_files` paths (bare `<uuid>.<ext>` keys with
  /// no bucket/folder prefix) originally stored on the pre-Supabase server.
  static bool isLegacyUnmigratedPath(String? storagePath) {
    final clean = (storagePath ?? '').trim();
    if (clean.isEmpty) return false;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return false;
    }
    return !clean.contains('/');
  }

  /// Resolves the byte length of [part] without reading a Web readStream.
  static Future<int> resolveUploadSize(UploadPart part) async {
    if (part.bytes.isNotEmpty) return part.bytes.length;
    if (!kIsWeb && part.filePath != null && part.filePath!.isNotEmpty) {
      final fileSize = await getLocalFileSize(part.filePath!);
      if (fileSize != null) return fileSize;
    }
    return part.size;
  }

  /// Translates HTTP 413 / Storage size rejections into an actionable error.
  static CrmStorageException mapUploadError(
    Object error,
    String filename,
    int sizeBytes,
  ) {
    if (error is CrmStorageException) return error;
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('413') ||
        lower.contains('maximum size exceeded') ||
        lower.contains('payload too large')) {
      return CrmStorageException(
        'File "$filename" (${formatFileSize(sizeBytes)}) exceeds Supabase Storage\'s '
        'current 50 MB upload limit. Compress or split it to <= 50 MB, or raise '
        'the file size limit in Supabase Storage settings.',
        statusCode: 413,
      );
    }
    return CrmStorageException('Upload failed for "$filename": $raw');
  }

  /// Uploads [part] to `chat_attachments/crm_files/...`.
  /// - Files > 6 MB stream in 6 MB TUS resumable chunks so neither native nor
  ///   Web buffers large files in memory, and size-limit rejections fail on the
  ///   0-byte creation header before payload transfer.
  /// - Files <= 6 MB read asynchronously and upload directly via `uploadBinary`.
  static Future<String> uploadFile(
    UploadPart part, {
    void Function(double progress)? onProgress,
  }) async {
    await ensureAuth();
    final supabase = Supabase.instance.client;
    final storagePath = buildStoragePath(part.filename);
    final mime = getMimeType(part.filename);
    final totalSize = await resolveUploadSize(part);

    if (totalSize <= 0) {
      throw CrmStorageException(
        'Cannot upload empty or unreadable file "${part.filename}". Please select a valid file.',
      );
    }

    try {
      if (totalSize > tusThresholdBytes) {
        await _uploadViaTus(
          supabase: supabase,
          part: part,
          storagePath: storagePath,
          mime: mime,
          totalSize: totalSize,
          onProgress: onProgress,
        );
        return storagePath;
      }

      final data = await _readAllBytesSmall(part);
      if (data.isEmpty) {
        throw CrmStorageException(
          'Cannot upload empty file "${part.filename}". Please select a valid file.',
        );
      }

      await supabase.storage.from(primaryBucket).uploadBinary(
            storagePath,
            data,
            fileOptions: FileOptions(
              contentType: mime,
              upsert: true,
            ),
          );
      onProgress?.call(1.0);
      return storagePath;
    } catch (e) {
      throw mapUploadError(e, part.filename, totalSize);
    }
  }

  /// Uploads [parts] sequentially with per-file progress and deletes any
  /// already-uploaded objects if a later file fails, preventing orphan blobs.
  static Future<List<String>> uploadBatch(
    List<UploadPart> parts, {
    CrmBatchUploadProgress? onProgress,
  }) async {
    if (parts.isEmpty) return const <String>[];

    for (final part in parts) {
      if (part.streamConsumed) {
        throw CrmStorageException(
          'File stream for "${part.filename}" was already read. Please re-select the file.',
        );
      }
      final size = await resolveUploadSize(part);
      if (size <= 0) {
        throw CrmStorageException(
          'Cannot upload empty or unreadable file "${part.filename}". Please select a valid file.',
        );
      }
    }

    final uploadedPaths = <String>[];
    try {
      for (var i = 0; i < parts.length; i++) {
        final part = parts[i];
        onProgress?.call(i, parts.length, 0.0, part.filename);
        final path = await uploadFile(
          part,
          onProgress: (p) => onProgress?.call(i, parts.length, p, part.filename),
        );
        uploadedPaths.add(path);
      }
      return uploadedPaths;
    } catch (_) {
      await deleteFiles(uploadedPaths);
      rethrow;
    }
  }

  static Future<Uint8List> _readAllBytesSmall(UploadPart part) async {
    if (part.bytes.isNotEmpty) {
      return part.bytes is Uint8List
          ? part.bytes as Uint8List
          : Uint8List.fromList(part.bytes);
    }

    if (!kIsWeb && part.filePath != null && part.filePath!.isNotEmpty) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in openLocalFileStream(part.filePath!)) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    if (part.readStream != null) {
      if (part.streamConsumed) {
        throw CrmStorageException(
          'File stream for "${part.filename}" was already read. Please re-select the file.',
        );
      }
      part.markStreamConsumed();
      final builder = BytesBuilder(copy: false);
      await for (final chunk in part.readStream!) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    return Uint8List(0);
  }

  static Map<String, String> _buildAuthHeaders(SupabaseClient supabase) {
    final headers = Map<String, String>.from(supabase.storage.headers);
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  static Future<void> _uploadViaTus({
    required SupabaseClient supabase,
    required UploadPart part,
    required String storagePath,
    required String mime,
    required int totalSize,
    void Function(double progress)? onProgress,
  }) async {
    final baseStorageUrl = supabase.storage.url.replaceFirst(RegExp(r'/+$'), '');
    final tusEndpoint = Uri.parse('$baseStorageUrl/upload/resumable');
    final authHeaders = _buildAuthHeaders(supabase);

    final uploadMetadata = [
      'bucketName ${base64Encode(utf8.encode(primaryBucket))}',
      'objectName ${base64Encode(utf8.encode(storagePath))}',
      'contentType ${base64Encode(utf8.encode(mime))}',
      'cacheControl ${base64Encode(utf8.encode('3600'))}',
    ].join(',');

    final client = http.Client();
    Uri? uploadUri;
    try {
      final createResp = await client
          .post(
            tusEndpoint,
            headers: {
              ...authHeaders,
              'Tus-Resumable': '1.0.0',
              'Upload-Length': '$totalSize',
              'Upload-Metadata': uploadMetadata,
              'x-upsert': 'true',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (createResp.statusCode != 201 && createResp.statusCode != 200) {
        if (createResp.statusCode == 413 ||
            createResp.body.toLowerCase().contains('maximum size exceeded')) {
          throw CrmStorageException(
            'File "${part.filename}" (${formatFileSize(totalSize)}) exceeds Supabase Storage\'s '
            'current 50 MB upload limit. Compress or split it to <= 50 MB, or raise '
            'the file size limit in Supabase Storage settings.',
            statusCode: 413,
          );
        }
        throw CrmStorageException(
          'Storage upload initialization failed (${createResp.statusCode}): ${createResp.body}',
          statusCode: createResp.statusCode,
        );
      }

      final location = createResp.headers['location'];
      if (location == null || location.isEmpty) {
        throw CrmStorageException('Storage TUS response did not return an upload Location.');
      }
      uploadUri = tusEndpoint.resolve(location);

      int offset = 0;
      await for (final chunk in _iterChunks(part, totalSize, tusChunkSizeBytes)) {
        offset = await _patchTusChunkWithRetry(
          client: client,
          uploadUri: uploadUri,
          authHeaders: authHeaders,
          offset: offset,
          chunk: chunk,
        );
        onProgress?.call((offset / totalSize).clamp(0.0, 1.0));
      }

      if (offset != totalSize) {
        throw CrmStorageException(
          'Upload incomplete for "${part.filename}" ($offset of $totalSize bytes uploaded).',
        );
      }
    } catch (e) {
      if (uploadUri != null) {
        try {
          await client.delete(
            uploadUri,
            headers: {...authHeaders, 'Tus-Resumable': '1.0.0'},
          );
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Uint8List> _iterChunks(
    UploadPart part,
    int totalSize,
    int chunkSize,
  ) async* {
    if (part.bytes.isNotEmpty) {
      final raw = part.bytes is Uint8List
          ? part.bytes as Uint8List
          : Uint8List.fromList(part.bytes);
      int offset = 0;
      while (offset < raw.length) {
        final end = (offset + chunkSize).clamp(0, raw.length);
        yield Uint8List.sublistView(raw, offset, end);
        offset = end;
      }
      return;
    }

    if (!kIsWeb && part.filePath != null && part.filePath!.isNotEmpty) {
      int offset = 0;
      while (offset < totalSize) {
        final end = (offset + chunkSize).clamp(0, totalSize);
        final builder = BytesBuilder(copy: false);
        await for (final piece in openLocalFileStream(part.filePath!, offset, end)) {
          builder.add(piece);
        }
        final chunk = builder.takeBytes();
        if (chunk.isEmpty) break;
        yield chunk;
        offset += chunk.length;
      }
      return;
    }

    if (part.readStream != null) {
      if (part.streamConsumed) {
        throw CrmStorageException(
          'File stream for "${part.filename}" was already read. Please re-select the file.',
        );
      }
      part.markStreamConsumed();
      final iterator = StreamIterator<List<int>>(part.readStream!);
      var pending = BytesBuilder(copy: false);
      try {
        while (await iterator.moveNext()) {
          final slice = iterator.current;
          if (slice.isEmpty) continue;
          pending.add(slice);
          if (pending.length >= chunkSize) {
            final buffered = pending.takeBytes();
            var pos = 0;
            while (buffered.length - pos >= chunkSize) {
              yield Uint8List.sublistView(buffered, pos, pos + chunkSize);
              pos += chunkSize;
            }
            if (pos < buffered.length) {
              pending.add(Uint8List.sublistView(buffered, pos));
            }
          }
        }
        if (pending.length > 0) {
          yield pending.takeBytes();
        }
      } finally {
        await iterator.cancel();
      }
      return;
    }

    throw CrmStorageException('No readable data source available for "${part.filename}".');
  }

  static Future<int> _patchTusChunkWithRetry({
    required http.Client client,
    required Uri uploadUri,
    required Map<String, String> authHeaders,
    required int offset,
    required Uint8List chunk,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await client
            .patch(
              uploadUri,
              headers: {
                ...authHeaders,
                'Tus-Resumable': '1.0.0',
                'Upload-Offset': '$offset',
                'Content-Type': 'application/offset+octet-stream',
              },
              body: chunk,
            )
            .timeout(const Duration(minutes: 2));

        if (resp.statusCode == 204 || resp.statusCode == 200) {
          final parsed = int.tryParse(resp.headers['upload-offset'] ?? '');
          return parsed ?? (offset + chunk.length);
        }

        if (resp.statusCode >= 500 && attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        throw CrmStorageException(
          'Chunk upload failed (${resp.statusCode}): ${resp.body}',
          statusCode: resp.statusCode,
        );
      } catch (e) {
        if (e is CrmStorageException && (e.statusCode ?? 500) < 500) {
          rethrow;
        }
        lastError = e;
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    throw CrmStorageException('Chunk upload failed after $maxAttempts retries: $lastError');
  }

  /// Resolves bucket + object path inside Supabase Storage for [storagePath].
  static ({String bucket, String path})? resolveBucketAndPath(String storagePath) {
    var clean = storagePath.trim();
    if (clean.isEmpty ||
        clean.startsWith('http://') ||
        clean.startsWith('https://')) {
      return null;
    }
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('uploads/')) {
      clean = clean.substring('uploads/'.length);
    }
    if (clean.isEmpty) return null;

    if (clean.startsWith('crm_files/')) {
      return (bucket: primaryBucket, path: clean);
    }
    if (clean.startsWith('chat_attachments/')) {
      return (
        bucket: primaryBucket,
        path: clean.substring('chat_attachments/'.length),
      );
    }
    if (clean.startsWith('dev_crm_files/')) {
      return (
        bucket: 'dev_crm_files',
        path: clean.substring('dev_crm_files/'.length),
      );
    }
    return (bucket: primaryBucket, path: clean);
  }

  /// Best-effort deletion of uploaded objects in `chat_attachments` when files
  /// or parent tasks/work items are removed. Silently skips external/legacy paths.
  static Future<void> deleteFiles(Iterable<String?> storagePaths) async {
    final chatAttachmentPaths = <String>[];
    for (final raw in storagePaths) {
      if (raw == null || raw.trim().isEmpty) continue;
      if (isLegacyUnmigratedPath(raw)) continue;
      final resolved = resolveBucketAndPath(raw);
      if (resolved == null) continue;
      if (resolved.bucket == primaryBucket &&
          resolved.path.startsWith('crm_files/')) {
        chatAttachmentPaths.add(resolved.path);
      }
    }
    if (chatAttachmentPaths.isEmpty) return;

    try {
      await ensureAuth();
      await Supabase.instance.client.storage
          .from(primaryBucket)
          .remove(chatAttachmentPaths);
    } catch (e) {
      debugPrint('[CrmStorage] Cleanup delete error (ignored): $e');
    }
  }

  /// Pure URL builder (testable without initializing Supabase).
  static String buildDownloadUrl(
    String storagePath, {
    String? filename,
    required String Function(String bucket, String objectPath) resolvePublicUrl,
  }) {
    final trimmed = storagePath.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      if (filename != null &&
          filename.isNotEmpty &&
          !uri.queryParameters.containsKey('download')) {
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['download'] = filename;
        return uri.replace(queryParameters: newParams).toString();
      }
      return trimmed;
    }

    final resolved = resolveBucketAndPath(trimmed);
    if (resolved == null) return '';

    final publicUrl = resolvePublicUrl(resolved.bucket, resolved.path);
    final fn = filename != null && filename.isNotEmpty
        ? filename
        : (resolved.path.contains('/')
            ? resolved.path.split('/').last
            : resolved.path);
    if (fn.isEmpty) return publicUrl;

    final uri = Uri.parse(publicUrl);
    final params = Map<String, String>.from(uri.queryParameters);
    params['download'] = fn;
    return uri.replace(queryParameters: params).toString();
  }

  /// Constructs a full download URL for the stored file with `?download=<name>`.
  static String getDownloadUrl(String storagePath, {String? filename}) {
    final supabase = Supabase.instance.client;
    return buildDownloadUrl(
      storagePath,
      filename: filename,
      resolvePublicUrl: (bucket, path) =>
          supabase.storage.from(bucket).getPublicUrl(path),
    );
  }

  /// Checks whether [effectiveUrl] exists in Storage before launching download.
  static Future<DownloadCheckResult> checkDownloadable(
    String effectiveUrl, {
    String? storagePath,
  }) async {
    final isLegacy = isLegacyUnmigratedPath(storagePath);
    try {
      final resp = await http
          .head(Uri.parse(effectiveUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return DownloadCheckResult(
          status: DownloadAvailabilityStatus.available,
          statusCode: resp.statusCode,
          isLegacyPath: isLegacy,
        );
      }
      if (resp.statusCode == 400 || resp.statusCode == 404) {
        return DownloadCheckResult(
          status: DownloadAvailabilityStatus.missing,
          statusCode: resp.statusCode,
          isLegacyPath: isLegacy,
        );
      }
      return DownloadCheckResult(
        status: DownloadAvailabilityStatus.unverifiable,
        statusCode: resp.statusCode,
        isLegacyPath: isLegacy,
      );
    } catch (e) {
      debugPrint('[CrmStorage] HEAD check skipped/failed: $e');
      return DownloadCheckResult(
        status: DownloadAvailabilityStatus.unverifiable,
        isLegacyPath: isLegacy,
      );
    }
  }
}
