/// Utility functions for Supabase storage file operations and sanitization.

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
