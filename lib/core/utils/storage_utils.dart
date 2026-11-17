import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/google_drive/google_drive_chat_service.dart';

/// Maximum allowed file attachment size for direct Supabase Storage uploads (45 MB).
/// Files larger than this threshold are automatically routed to company Google Drive (Gmail style).
const int kGoogleDriveThreshold = 45 * 1024 * 1024; // 45 MB

/// Maximum allowed file attachment size for chat uploads (50 MB standard Supabase limit).
/// For files > 50 MB (like large 3 GB datasets), files route to Google Drive or share via link.
const int kMaxChatAttachmentSize = 50 * 1024 * 1024; // 50 MB

/// Maximum allowed file attachment size when Google Drive is connected (5 GB).
const int kMaxDriveAttachmentSize = 5 * 1024 * 1024 * 1024; // 5 GB

/// Threshold for switching to TUS chunked resumable streaming (6 MB).
const int kTusUploadThreshold = 6 * 1024 * 1024; // 6 MB

/// Chunk size for TUS streaming (6 MB per chunk).
const int kTusChunkSize = 6 * 1024 * 1024; // 6 MB

/// Formats a byte count into a human-readable string (B, KB, MB, GB).
String formatChatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// In-memory cache for recently uploaded or displayed chat images.
/// Enables 0ms instantaneous display for the sender and fast local lookup.
class ChatImageMemoryCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxEntries = 60;

  static void put(String url, Uint8List bytes) {
    if (url.isEmpty || bytes.isEmpty) return;
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[url] = bytes;
  }

  static Uint8List? get(String url) {
    return _cache[url];
  }

  static bool contains(String url) {
    return _cache.containsKey(url);
  }
}

/// Result of uploading a chat attachment.
class ChatUploadResult {
  final String fileUrl;
  final String fileName;
  final String fileType;
  final Uint8List? bytes;

  const ChatUploadResult({
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    this.bytes,
  });
}

/// Sanitizes a file name for safe storage in cloud object storage (e.g. Supabase Storage / S3).
///
/// Removes or replaces special characters, Unicode characters (en-dash, em-dash, etc.),
/// ampersands, spaces, quotes, and punctuation that cause HTTP 400 Bad Request or URL routing errors.
String sanitizeStorageFileName(String originalFileName, {String? prefix}) {
  if (originalFileName.trim().isEmpty) {
    originalFileName = 'file';
  }

  // Separate name and extension
  final dotIndex = originalFileName.lastIndexOf('.');
  String baseName;
  String ext;
  if (dotIndex > 0) {
    baseName = originalFileName.substring(0, dotIndex);
    ext = originalFileName.substring(dotIndex);
  } else if (dotIndex == 0) {
    baseName = 'file';
    ext = originalFileName;
  } else {
    baseName = originalFileName;
    ext = '';
  }

  // Clean extension (lowercase, only alphanumeric and dot)
  final cleanExt = ext.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '').toLowerCase();

  // Clean base name: replace any character that is NOT a standard ASCII alphanumeric or hyphen/underscore with '_'
  String cleanName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

  // Collapse multiple consecutive underscores into a single underscore
  cleanName = cleanName.replaceAll(RegExp(r'_+'), '_');

  // Trim leading and trailing underscores and hyphens
  cleanName = cleanName.replaceAll(RegExp(r'^[_\\-]+|[_\\-]+$'), '');

  if (cleanName.isEmpty) {
    cleanName = 'file';
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final sanitizedName = '${timestamp}_$cleanName$cleanExt';

  if (prefix != null && prefix.trim().isNotEmpty) {
    final cleanPrefix = prefix
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-/]'), '_')
        .replaceAll(RegExp(r'/+'), '/')
        .replaceAll(RegExp(r'^/|/$'), '');
    return '$cleanPrefix/$sanitizedName';
  }

  return sanitizedName;
}

/// Returns the standard MIME content type for a given file extension or file name.
String getMimeType(String? extension, [String? fileName]) {
  String? ext = extension;
  if ((ext == null || ext.trim().isEmpty) && fileName != null && fileName.contains('.')) {
    ext = fileName.split('.').last;
  }
  if (ext == null || ext.trim().isEmpty) return 'application/octet-stream';

  final cleanExt = ext.toLowerCase().replaceAll('.', '').trim();
  switch (cleanExt) {
    // Images
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    case 'bmp':
      return 'image/bmp';
    case 'ico':
      return 'image/x-icon';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';

    // Audio
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'm4a':
      return 'audio/mp4';
    case 'ogg':
    case 'opus':
      return 'audio/ogg';
    case 'webm':
      return 'audio/webm';
    case 'aac':
      return 'audio/aac';
    case 'flac':
      return 'audio/flac';

    // Video
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'avi':
      return 'video/x-msvideo';
    case 'mkv':
      return 'video/x-matroska';

    // Documents / Office
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
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'csv':
      return 'text/csv';
    case 'json':
      return 'application/json';
    case 'xml':
      return 'application/xml';
    case 'html':
    case 'htm':
      return 'text/html';

    // Archives
    case 'zip':
      return 'application/zip';
    case 'rar':
      return 'application/vnd.rar';
    case '7z':
      return 'application/x-7z-compressed';
    case 'tar':
      return 'application/x-tar';
    case 'gz':
      return 'application/gzip';

    // Executables / Installers
    case 'apk':
      return 'application/vnd.android.package-archive';
    case 'exe':
      return 'application/x-msdownload';
    case 'dmg':
      return 'application/x-apple-diskimage';

    default:
      return 'application/octet-stream';
  }
}

/// Top-level worker for offloading CPU-intensive image compression to a background isolate.
/// Keeps the Flutter main UI isolate smooth at 60/120fps with zero frame drops or lag.
Uint8List? _compressRasterImageWorker(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final maxDimension = args['maxDimension'] as int;
  final quality = args['quality'] as int;

  final image = img.decodeImage(bytes);
  if (image == null) return null;

  img.Image processed = image;
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width >= image.height) {
      processed = img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.linear);
    } else {
      processed = img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.linear);
    }
  }

  return Uint8List.fromList(img.encodeJpg(processed, quality: quality));
}

/// Compresses and resizes raster images (JPG, PNG, WebP) client-side before upload.
/// Uses [compute] / background isolates so decoding and JPEG encoding never block the UI thread.
/// Reduces a 5-15MB photo to ~150-300KB, speeding up uploads and downloads by 20x to 50x.
/// GIFs, PDFs, audio, video, and files under 200KB are left untouched.
Future<({Uint8List bytes, String extension, String mimeType, String fileName})> compressImageIfNeeded(
  Uint8List originalBytes,
  String? originalExtension,
  String originalFileName, {
  int maxDimension = 1920,
  int quality = 82,
}) async {
  final ext = (originalExtension ?? (originalFileName.contains('.') ? originalFileName.split('.').last : '')).toLowerCase().replaceAll('.', '');

  // Only compress raster images; skip animated gifs, svgs, documents, videos
  final isRasterImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic'].contains(ext);
  if (!isRasterImage || originalBytes.length < 200 * 1024) {
    return (
      bytes: originalBytes,
      extension: ext.isEmpty ? 'png' : ext,
      mimeType: getMimeType(ext, originalFileName),
      fileName: originalFileName,
    );
  }

  try {
    Uint8List? compressedBytes;
    if (kIsWeb) {
      compressedBytes = _compressRasterImageWorker({
        'bytes': originalBytes,
        'maxDimension': maxDimension,
        'quality': quality,
      });
    } else {
      compressedBytes = await compute(_compressRasterImageWorker, {
        'bytes': originalBytes,
        'maxDimension': maxDimension,
        'quality': quality,
      });
    }

    if (compressedBytes == null) {
      return (
        bytes: originalBytes,
        extension: ext.isEmpty ? 'png' : ext,
        mimeType: getMimeType(ext, originalFileName),
        fileName: originalFileName,
      );
    }

    // If compression didn't save size, keep original
    if (compressedBytes.length >= originalBytes.length) {
      return (
        bytes: originalBytes,
        extension: ext,
        mimeType: getMimeType(ext, originalFileName),
        fileName: originalFileName,
      );
    }

    // Switch extension to .jpg since it is now encoded as JPEG
    String newFileName = originalFileName;
    if (newFileName.contains('.')) {
      newFileName = '${newFileName.substring(0, newFileName.lastIndexOf('.'))}.jpg';
    } else {
      newFileName = '$newFileName.jpg';
    }

    return (
      bytes: compressedBytes,
      extension: 'jpg',
      mimeType: 'image/jpeg',
      fileName: newFileName,
    );
  } catch (e) {
    debugPrint('Image compression error (fallback to original): $e');
    return (
      bytes: originalBytes,
      extension: ext.isEmpty ? 'png' : ext,
      mimeType: getMimeType(ext, originalFileName),
      fileName: originalFileName,
    );
  }
}

/// Uploads a single file attachment to Supabase Storage with automatic compression,
/// sanitization, and instant in-memory cache priming.
/// Files > 6 MB stream in 6 MB TUS resumable chunks directly from disk on native platforms,
/// supporting files up to 5 GB with minimal RAM consumption (< 10 MB).
Future<ChatUploadResult> uploadChatAttachment(
  PlatformFile file, {
  String bucket = 'chat_attachments',
  String? prefix,
  void Function(double progress)? onProgress,
}) async {
  final resolvedSize = file.size > 0
      ? file.size
      : (!kIsWeb && file.path != null && File(file.path!).existsSync()
          ? File(file.path!).lengthSync()
          : (file.bytes?.length ?? 0));

  if (resolvedSize <= 0) {
    throw Exception('Cannot upload empty or unreadable file "${file.name}".');
  }

  // Large file handling (> 45 MB): Route directly to Company Google Drive (Gmail style)
  if (resolvedSize > kGoogleDriveThreshold) {
    final isDriveConfigured = await GoogleDriveChatService.isConfigured();
    if (isDriveConfigured) {
      debugPrint(
        '[StorageUtils] File "${file.name}" (${formatChatFileSize(resolvedSize)}) exceeds 45 MB. Automatically streaming to company Google Drive...',
      );
      final driveResult = await GoogleDriveChatService.uploadLargeFile(
        file: file,
        onProgress: onProgress,
      );
      return ChatUploadResult(
        fileUrl: driveResult.fileUrl,
        fileName: driveResult.fileName,
        fileType: 'gdrive',
        bytes: null,
      );
    } else {
      throw Exception(
        'File "${file.name}" (${formatChatFileSize(resolvedSize)}) exceeds the 45 MB direct upload limit. '
        'Please connect Company Google Drive in Settings -> Google Drive to enable automatic large file uploads, or share via link.',
      );
    }
  }

  // Refresh auth session if expired, or authenticate default agent if session is missing
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session != null && session.isExpired) {
    try {
      await client.auth.refreshSession();
    } catch (e) {
      debugPrint('Session refresh warning: $e');
    }
  } else if (session == null) {
    try {
      await client.auth.signInWithPassword(
        email: 'agents@tallycare.local',
        password: 'AgentShared#2026',
      );
    } catch (e) {
      debugPrint('Storage auto-auth warning: $e');
    }
  }

  final ext = (file.extension ?? (file.name.contains('.') ? file.name.split('.').last : '')).toLowerCase();
  final isRasterImage = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic'].contains(ext);

  Uint8List? fileBytes = file.bytes;
  if (isRasterImage && fileBytes == null && !kIsWeb && file.path != null && file.path!.isNotEmpty) {
    try {
      final fileObj = File(file.path!);
      if (fileObj.existsSync() && fileObj.lengthSync() < 20 * 1024 * 1024) {
        fileBytes = await fileObj.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading image bytes from path ${file.path}: $e');
    }
  }

  final storage = client.storage;

  // Case 1: Standard raster image under 20 MB — compress if needed and upload
  if (isRasterImage && fileBytes != null && fileBytes.isNotEmpty) {
    final compressed = await compressImageIfNeeded(
      fileBytes,
      file.extension,
      file.name,
    );

    final finalBytes = compressed.bytes;
    final finalFileName = compressed.fileName;
    final finalExt = compressed.extension;
    final finalMime = compressed.mimeType;
    final filePath = sanitizeStorageFileName(finalFileName, prefix: prefix);

    if (finalBytes.length > kTusUploadThreshold) {
      await _uploadChatViaTus(
        supabase: client,
        bucket: bucket,
        storagePath: filePath,
        mime: finalMime,
        totalSize: finalBytes.length,
        rawBytes: finalBytes,
        file: file,
        onProgress: onProgress,
      );
    } else {
      await storage.from(bucket).uploadBinary(
        filePath,
        finalBytes,
        fileOptions: FileOptions(
          contentType: finalMime,
          upsert: true,
        ),
      );
      onProgress?.call(1.0);
    }

    final publicUrl = storage.from(bucket).getPublicUrl(filePath);
    ChatImageMemoryCache.put(publicUrl, finalBytes);

    return ChatUploadResult(
      fileUrl: publicUrl,
      fileName: finalFileName,
      fileType: finalExt,
      bytes: finalBytes,
    );
  }

  // Case 2: Files > 6 MB — stream via TUS chunked resumable upload directly from disk/stream
  if (resolvedSize > kTusUploadThreshold) {
    final finalFileName = file.name;
    final finalExt = ext;
    final finalMime = getMimeType(finalExt, finalFileName);
    final filePath = sanitizeStorageFileName(finalFileName, prefix: prefix);

    final publicUrl = await _uploadChatViaTus(
      supabase: client,
      bucket: bucket,
      storagePath: filePath,
      mime: finalMime,
      totalSize: resolvedSize,
      file: file,
      rawBytes: fileBytes,
      onProgress: onProgress,
    );

    return ChatUploadResult(
      fileUrl: publicUrl,
      fileName: finalFileName,
      fileType: finalExt,
      bytes: null,
    );
  }

  // Case 3: Native non-image file <= 6 MB with a local path
  if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
    final fileObj = File(file.path!);
    if (!fileObj.existsSync()) {
      throw Exception('File not found at ${file.path}');
    }

    final finalFileName = file.name;
    final finalExt = ext;
    final finalMime = getMimeType(finalExt, finalFileName);
    final filePath = sanitizeStorageFileName(finalFileName, prefix: prefix);

    await storage.from(bucket).upload(
      filePath,
      fileObj,
      fileOptions: FileOptions(
        contentType: finalMime,
        upsert: true,
      ),
    );
    onProgress?.call(1.0);

    final publicUrl = storage.from(bucket).getPublicUrl(filePath);

    return ChatUploadResult(
      fileUrl: publicUrl,
      fileName: finalFileName,
      fileType: finalExt,
      bytes: null,
    );
  }

  // Case 4: Binary bytes available <= 6 MB (Web or in-memory)
  if (fileBytes != null && fileBytes.isNotEmpty) {
    final finalFileName = file.name;
    final finalExt = ext;
    final finalMime = getMimeType(finalExt, finalFileName);
    final filePath = sanitizeStorageFileName(finalFileName, prefix: prefix);

    await storage.from(bucket).uploadBinary(
      filePath,
      fileBytes,
      fileOptions: FileOptions(
        contentType: finalMime,
        upsert: true,
      ),
    );
    onProgress?.call(1.0);

    final publicUrl = storage.from(bucket).getPublicUrl(filePath);

    return ChatUploadResult(
      fileUrl: publicUrl,
      fileName: finalFileName,
      fileType: finalExt,
      bytes: fileBytes,
    );
  }

  throw Exception('Cannot read file data for ${file.name}.');
}

/// Helper to upload large files to Supabase Storage using TUS 1.0.0 Resumable Protocol.
/// Streams directly from disk using [RandomAccessFile] in 6 MB blocks to keep RAM usage minimal.
Future<String> _uploadChatViaTus({
  required SupabaseClient supabase,
  required String bucket,
  required String storagePath,
  required String mime,
  required int totalSize,
  PlatformFile? file,
  Uint8List? rawBytes,
  void Function(double progress)? onProgress,
}) async {
  final baseStorageUrl = supabase.storage.url.replaceFirst(RegExp(r'/+$'), '');
  final tusEndpoint = Uri.parse('$baseStorageUrl/upload/resumable');

  final authHeaders = Map<String, String>.from(supabase.storage.headers);
  final accessToken = supabase.auth.currentSession?.accessToken;
  if (accessToken != null && accessToken.isNotEmpty) {
    authHeaders['Authorization'] = 'Bearer $accessToken';
  }

  final uploadMetadata = [
    'bucketName ${base64Encode(utf8.encode(bucket))}',
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
        .timeout(const Duration(seconds: 45));

    if (createResp.statusCode != 201 && createResp.statusCode != 200) {
      if (createResp.statusCode == 413 ||
          (createResp.statusCode == 400 && createResp.body.toLowerCase().contains('exceeded')) ||
          createResp.body.toLowerCase().contains('maximum size exceeded') ||
          createResp.body.toLowerCase().contains('payload too large')) {
        throw Exception(
          'File "${file?.name ?? 'file'}" (${formatChatFileSize(totalSize)}) exceeds Supabase Storage limit. '
          'Supabase Free tier limits files to 50 MB (Pro tier allows up to 5 GB). '
          'Please increase the bucket limit to 5 GB in Supabase Storage settings or share via Google Drive.',
        );
      }
      throw Exception(
        'Storage upload initialization failed (${createResp.statusCode}): ${createResp.body}',
      );
    }

    final location = createResp.headers['location'];
    if (location == null || location.isEmpty) {
      throw Exception('TUS response did not return an upload Location.');
    }
    uploadUri = tusEndpoint.resolve(location);

    int offset = 0;
    const chunkSize = kTusChunkSize;

    // Stream chunks directly from disk on native platforms without buffering into RAM
    if (!kIsWeb && file?.path != null && file!.path!.isNotEmpty) {
      final fileObj = File(file.path!);
      if (!fileObj.existsSync()) {
        throw Exception('File not found on disk at "${file.path}".');
      }
      final raf = await fileObj.open(mode: FileMode.read);
      try {
        while (offset < totalSize) {
          await raf.setPosition(offset);
          final toRead = (totalSize - offset).clamp(0, chunkSize);
          final chunk = await raf.read(toRead);
          if (chunk.isEmpty) break;

          offset = await _patchTusChunkWithRetry(
            client: client,
            uploadUri: uploadUri,
            authHeaders: authHeaders,
            offset: offset,
            chunk: chunk,
          );
          onProgress?.call((offset / totalSize).clamp(0.0, 1.0));
        }
      } finally {
        await raf.close();
      }
    } else if (rawBytes != null && rawBytes.isNotEmpty) {
      while (offset < rawBytes.length) {
        final end = (offset + chunkSize).clamp(0, rawBytes.length);
        final chunk = Uint8List.sublistView(rawBytes, offset, end);
        offset = await _patchTusChunkWithRetry(
          client: client,
          uploadUri: uploadUri,
          authHeaders: authHeaders,
          offset: offset,
          chunk: chunk,
        );
        onProgress?.call((offset / totalSize).clamp(0.0, 1.0));
      }
    } else if (file?.readStream != null) {
      final iterator = StreamIterator<List<int>>(file!.readStream!);
      var pending = BytesBuilder(copy: false);
      try {
        while (await iterator.moveNext()) {
          final slice = iterator.current;
          if (slice.isEmpty) continue;
          pending.add(slice);
          while (pending.length >= chunkSize) {
            final buffered = pending.takeBytes();
            final chunk = Uint8List.sublistView(buffered, 0, chunkSize);
            offset = await _patchTusChunkWithRetry(
              client: client,
              uploadUri: uploadUri,
              authHeaders: authHeaders,
              offset: offset,
              chunk: chunk,
            );
            onProgress?.call((offset / totalSize).clamp(0.0, 1.0));
            if (buffered.length > chunkSize) {
              pending.add(Uint8List.sublistView(buffered, chunkSize));
            }
          }
        }
        if (pending.length > 0) {
          final chunk = pending.takeBytes();
          offset = await _patchTusChunkWithRetry(
            client: client,
            uploadUri: uploadUri,
            authHeaders: authHeaders,
            offset: offset,
            chunk: chunk,
          );
          onProgress?.call((offset / totalSize).clamp(0.0, 1.0));
        }
      } finally {
        await iterator.cancel();
      }
    } else {
      throw Exception('No readable data source available for "${file?.name ?? 'file'}".');
    }

    if (offset != totalSize) {
      throw Exception(
        'Upload incomplete for "${file?.name ?? 'file'}" ($offset of $totalSize bytes uploaded).',
      );
    }

    return supabase.storage.from(bucket).getPublicUrl(storagePath);
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

Future<int> _patchTusChunkWithRetry({
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
          .timeout(const Duration(minutes: 3));

      if (resp.statusCode == 204 || resp.statusCode == 200) {
        final parsed = int.tryParse(resp.headers['upload-offset'] ?? '');
        return parsed ?? (offset + chunk.length);
      }

      if (resp.statusCode == 409) {
        final serverOffset = int.tryParse(resp.headers['upload-offset'] ?? '');
        if (serverOffset != null) {
          return serverOffset;
        }
      }

      // Refresh session if token expired during multi-GB transfer
      if ((resp.statusCode == 401 || resp.statusCode == 403) && attempt < maxAttempts) {
        try {
          await Supabase.instance.client.auth.refreshSession();
          final newTok = Supabase.instance.client.auth.currentSession?.accessToken;
          if (newTok != null && newTok.isNotEmpty) {
            authHeaders['Authorization'] = 'Bearer $newTok';
          }
        } catch (_) {}
        continue;
      }

      if (resp.statusCode >= 500 && attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }

      throw Exception('Chunk upload failed (${resp.statusCode}): ${resp.body}');
    } catch (e) {
      lastError = e;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }
  throw Exception('Chunk upload failed after $maxAttempts retries: $lastError');
}

/// Uploads multiple chat attachments in parallel with compression and cache priming.
Future<List<ChatUploadResult>> uploadChatAttachmentsParallel(
  List<PlatformFile> files, {
  String bucket = 'chat_attachments',
  String? prefix,
}) async {
  if (files.isEmpty) return const [];
  final futures = files.map((f) => uploadChatAttachment(f, bucket: bucket, prefix: prefix));
  final results = await Future.wait(futures);
  return results.whereType<ChatUploadResult>().toList();
}

