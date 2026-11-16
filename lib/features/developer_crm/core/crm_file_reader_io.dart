import 'dart:io';

Future<int?> getLocalFileSize(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  return file.length();
}

Stream<List<int>> openLocalFileStream(String path, [int start = 0, int? end]) {
  return File(path).openRead(start, end);
}

