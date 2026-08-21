// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:http/http.dart' as http;

Future<void> downloadFileDirectly(String url, String fileName) async {
  // Ensure filename has an extension so the browser knows how to save it
  final effectiveName = _ensureExtension(url, fileName);
  debugPrint('[Download] Starting download: $effectiveName from $url');

  // Strategy 1: Fetch bytes → create Blob → trigger anchor download.
  // Uses the exact same pattern as backup_web_download.dart (which works).
  // Requires the Supabase "chat_attachments" bucket to be set as PUBLIC.
  try {
    final response = await http.get(Uri.parse(url));
    debugPrint('[Download] HTTP status: ${response.statusCode}, bytes: ${response.bodyBytes.length}');

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      // Must use Uint8List.fromList — direct .toJS on bodyBytes is unreliable
      final uint8 = Uint8List.fromList(response.bodyBytes);
      final blob = web.Blob(
        [uint8.toJS].toJS,
        web.BlobPropertyBag(type: _mimeFromName(effectiveName)),
      );
      final blobUrl = web.URL.createObjectURL(blob);
      debugPrint('[Download] Blob URL created, triggering anchor click');

      final anchor = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = blobUrl
        ..download = effectiveName;
      anchor.style.display = 'none';
      web.document.body!.append(anchor);
      anchor.click();
      anchor.remove();

      // Give browser a moment before revoking the blob URL
      Future.delayed(const Duration(milliseconds: 500), () {
        web.URL.revokeObjectURL(blobUrl);
      });
      debugPrint('[Download] Success via blob strategy');
      return;
    } else {
      debugPrint('[Download] Bad response: ${response.statusCode} — falling back to window.open');
    }
  } catch (e) {
    // Network error or CORS — fall through to strategy 2
    debugPrint('[Download] Fetch failed: $e — falling back to window.open');
  }

  // Strategy 2: open the URL in a new tab.
  // For Supabase public buckets, this triggers the browser's native
  // download/save dialog for binary files (zip, apk, exe, etc.)
  debugPrint('[Download] Using window.open fallback');
  web.window.open(url, '_blank');
}

/// If fileName has no extension, extract one from the URL path.
String _ensureExtension(String url, String fileName) {
  if (fileName.contains('.')) return fileName;
  try {
    final last = Uri.parse(url).pathSegments.last;
    final dotIdx = last.lastIndexOf('.');
    if (dotIdx > 0) return '$fileName${last.substring(dotIdx)}';
  } catch (_) {}
  return fileName;
}

/// Map file extension to MIME type for the Blob.
String _mimeFromName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.rar')) return 'application/vnd.rar';
  if (lower.endsWith('.7z')) return 'application/x-7z-compressed';
  if (lower.endsWith('.tar')) return 'application/x-tar';
  if (lower.endsWith('.gz')) return 'application/gzip';
  if (lower.endsWith('.apk')) return 'application/vnd.android.package-archive';
  if (lower.endsWith('.exe')) return 'application/x-msdownload';
  if (lower.endsWith('.dmg')) return 'application/x-apple-diskimage';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.avi')) return 'video/x-msvideo';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.txt')) return 'text/plain';
  if (lower.endsWith('.csv')) return 'text/csv';
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.xml')) return 'application/xml';
  if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
  return 'application/octet-stream';
}
