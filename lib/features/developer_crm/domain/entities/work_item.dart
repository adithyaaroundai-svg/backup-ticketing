import '../../core/parse_utils.dart';

class WorkItemFile {
  final int id;
  final int? workItemId;
  final String filename;
  final String? storagePath;
  final String category;
  final String? comment;
  final String? uploadedAt;

  WorkItemFile({
    required this.id,
    this.workItemId,
    required this.filename,
    this.storagePath,
    required this.category,
    this.comment,
    this.uploadedAt,
  });

  factory WorkItemFile.fromJson(Map<String, dynamic> json) => WorkItemFile(
        id: asInt(json['id']),
        workItemId: asIntOrNull(json['work_item_id']),
        filename: asString(json['filename']),
        storagePath: asStringOrNull(json['storage_path']),
        category: asString(json['category'], 'other'),
        comment: asStringOrNull(json['comment']),
        uploadedAt: asStringOrNull(json['uploaded_at']),
      );
}

/// A code block reference as embedded in a WorkItem (no `content` — fetch
/// that separately via `POST /api/work-items/:id/reveal`).
class WorkItemCodeRef {
  final int id;
  final String? language;
  final String? filename;

  WorkItemCodeRef({required this.id, this.language, this.filename});

  factory WorkItemCodeRef.fromJson(Map<String, dynamic> json) => WorkItemCodeRef(
        id: asInt(json['id']),
        language: asStringOrNull(json['language']),
        filename: asStringOrNull(json['filename']),
      );
}

/// A revealed code block, from `POST /api/work-items/:id/reveal`.
class RevealedCodeBlock {
  final String? language;
  final String? filename;
  final String content;

  RevealedCodeBlock({this.language, this.filename, required this.content});

  factory RevealedCodeBlock.fromJson(Map<String, dynamic> json) => RevealedCodeBlock(
        language: asStringOrNull(json['language']),
        filename: asStringOrNull(json['filename']),
        content: asString(json['content']),
      );
}

class WorkItem {
  final int id;
  final int? clientId;
  final int? projectId;
  final String title;
  final String? description;
  final int? authorId;
  final String? authorName;
  final String? source;
  final String? createdAt;
  final List<WorkItemCodeRef> code;
  final List<WorkItemFile> files;

  WorkItem({
    required this.id,
    this.clientId,
    this.projectId,
    required this.title,
    this.description,
    this.authorId,
    this.authorName,
    this.source,
    this.createdAt,
    this.code = const [],
    this.files = const [],
  });

  factory WorkItem.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code'];
    final code = <WorkItemCodeRef>[];
    if (rawCode is List) {
      for (final c in rawCode) {
        if (c is Map) code.add(WorkItemCodeRef.fromJson(Map<String, dynamic>.from(c)));
      }
    }
    final rawFiles = json['files'];
    final files = <WorkItemFile>[];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        if (f is Map) files.add(WorkItemFile.fromJson(Map<String, dynamic>.from(f)));
      }
    }
    return WorkItem(
      id: asInt(json['id']),
      clientId: asIntOrNull(json['client_id']),
      projectId: asIntOrNull(json['project_id']),
      title: asString(json['title']),
      description: asStringOrNull(json['description']),
      authorId: asIntOrNull(json['author_id']),
      authorName: asStringOrNull(json['author_name']),
      source: asStringOrNull(json['source']),
      createdAt: asStringOrNull(json['created_at']),
      code: code,
      files: files,
    );
  }
}
