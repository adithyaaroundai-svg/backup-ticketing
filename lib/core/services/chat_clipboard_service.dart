import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ChatClipboardService {
  static void registerPasteListener({
    required void Function(PlatformFile file) onFileReceived,
  }) {
    ClipboardEvents.instance?.registerPasteEventListener((event) async {
      try {
        final reader = await event.getClipboardReader();
        
        for (final item in reader.items) {
          // 1. Try fileUri first (handles ANY file copied on Desktop)
          if (item.canProvide(Formats.fileUri)) {
            final fileUri = await item.readValue(Formats.fileUri);
            if (fileUri != null && !kIsWeb) {
              final path = fileUri.toFilePath();
              final xfile = XFile(path);
              try {
                final bytes = await xfile.readAsBytes();
                onFileReceived(PlatformFile(
                  name: fileUri.pathSegments.isNotEmpty ? fileUri.pathSegments.last : 'pasted_file.bin',
                  size: bytes.length,
                  bytes: bytes,
                ));
                return;
              } catch (e) {
                debugPrint('Could not read clipboard file: $e');
              }
            }
          }
          
          // 2. Try common formats (handles images on Web and Desktop)
          final fallbackFormats = [
            Formats.png,
            Formats.jpeg,
            Formats.webp,
            Formats.gif,
            Formats.pdf,
          ];
          
          for (final format in fallbackFormats) {
            if (item.canProvide(format)) {
              item.getFile(format, (file) async {
                final bytes = await file.readAll();
                
                String ext = 'bin';
                if (format == Formats.png) {
                  ext = 'png';
                } else if (format == Formats.jpeg) {
                  ext = 'jpg';
                } else if (format == Formats.webp) {
                  ext = 'webp';
                } else if (format == Formats.gif) {
                  ext = 'gif';
                } else if (format == Formats.pdf) {
                  ext = 'pdf';
                }
                
                onFileReceived(PlatformFile(
                  name: file.fileName ?? 'pasted_file.$ext',
                  size: bytes.length,
                  bytes: bytes,
                ));
              });
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('SuperClipboard paste error: $e');
      }
    });
  }
}
