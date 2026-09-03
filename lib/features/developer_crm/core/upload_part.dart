import '../core/upload_part.dart';
/// A single file to attach to an upload request. Bytes are used (rather
/// than a file path) so this works uniformly on web and native platforms.
class UploadPart {
  final String field;
  final String filename;
  final List<int> bytes;

  UploadPart({required this.field, required this.filename, required this.bytes});
}
