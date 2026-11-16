import 'package:file_picker/file_picker.dart';

/// A single file to attach to an upload request.
/// Holds [filePath] for native chunked disk uploads and [readStream] / [bytes]
/// for Web uploads without forcing entire large archives into RAM upfront.
class UploadPart {
  final String field;
  final String filename;
  final List<int> bytes;
  final Stream<List<int>>? readStream;
  final String? filePath;
  final int size;
  bool _streamConsumed = false;

  UploadPart({
    required this.field,
    required this.filename,
    List<int>? bytes,
    this.readStream,
    this.filePath,
    this.size = 0,
  }) : bytes = bytes ?? const [];

  bool get streamConsumed => _streamConsumed;
  void markStreamConsumed() {
    _streamConsumed = true;
  }

  factory UploadPart.fromPlatformFile(PlatformFile f, {required String field}) {
    return UploadPart(
      field: field,
      filename: f.name,
      bytes: f.bytes,
      readStream: f.readStream,
      filePath: f.path,
      size: f.size > 0 ? f.size : (f.bytes?.length ?? 0),
    );
  }
}
