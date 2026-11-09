import 'package:file_picker/file_picker.dart';

/// A single file to attach to an upload request.
/// Holds [filePath] for native streaming uploads of large files (e.g. ZIPs of any size)
/// without memory overhead, and [bytes] for web platform uploads.
class UploadPart {
  final String field;
  final String filename;
  final List<int> bytes;
  final String? filePath;
  final int size;

  UploadPart({
    required this.field,
    required this.filename,
    List<int>? bytes,
    this.filePath,
    this.size = 0,
  }) : bytes = bytes ?? const [];

  factory UploadPart.fromPlatformFile(PlatformFile f, {required String field}) {
    return UploadPart(
      field: field,
      filename: f.name,
      bytes: f.bytes,
      filePath: f.path,
      size: f.size > 0 ? f.size : (f.bytes?.length ?? 0),
    );
  }
}
