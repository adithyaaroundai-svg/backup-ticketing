import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Compresses and resizes raster images (JPG, PNG, WebP) client-side before upload.
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
    final image = img.decodeImage(originalBytes);
    if (image == null) {
      return (
        bytes: originalBytes,
        extension: ext.isEmpty ? 'png' : ext,
        mimeType: getMimeType(ext, originalFileName),
        fileName: originalFileName,
      );
    }

    img.Image processed = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width >= image.height) {
        processed = img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.linear);
      } else {
        processed = img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.linear);
      }
    }

    final compressedBytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));

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
Future<ChatUploadResult?> uploadChatAttachment(
  PlatformFile file, {
  String bucket = 'chat_attachments',
  String? prefix,
}) async {
  try {
    Uint8List? fileBytes = file.bytes;
    if (fileBytes == null && !kIsWeb && file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }

    if (fileBytes == null || fileBytes.isEmpty) {
      debugPrint('Error: File bytes are empty for ${file.name}');
      return null;
    }

    // Compress image if applicable
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
    final storage = Supabase.instance.client.storage;

    await storage.from(bucket).uploadBinary(
      filePath,
      finalBytes,
      fileOptions: FileOptions(
        contentType: finalMime,
        upsert: false,
      ),
    );

    final publicUrl = storage.from(bucket).getPublicUrl(filePath);

    // Prime the in-memory cache so this client can view the image instantly with 0ms delay!
    ChatImageMemoryCache.put(publicUrl, finalBytes);

    return ChatUploadResult(
      fileUrl: publicUrl,
      fileName: finalFileName,
      fileType: finalExt,
      bytes: finalBytes,
    );
  } catch (e) {
    debugPrint('uploadChatAttachment error: $e');
    return null;
  }
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

