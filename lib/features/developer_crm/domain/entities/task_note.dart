import '../../core/parse_utils.dart';

class TaskNote {
  final int id;
  final int taskId;
  final String noteDate;
  final String body;
  final int? createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String? authorName;

  TaskNote({
    required this.id,
    required this.taskId,
    required this.noteDate,
    required this.body,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.authorName,
  });

  factory TaskNote.fromJson(Map<String, dynamic> json) => TaskNote(
        id: asInt(json['id']),
        taskId: asInt(json['task_id']),
        noteDate: asString(json['note_date']),
        body: asString(json['body']),
        createdBy: asIntOrNull(json['created_by']),
        createdAt: asStringOrNull(json['created_at']),
        updatedAt: asStringOrNull(json['updated_at']),
        authorName: asStringOrNull(json['author_name']),
      );
}
