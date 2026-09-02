import '../../core/parse_utils.dart';

class TaskStatusHistoryEntry {
  final int id;
  final int taskId;
  final String? fromStatus;
  final String toStatus;
  final String? message;
  final int? changedBy;
  final String? changedAt;
  final String? changedByName;

  TaskStatusHistoryEntry({
    required this.id,
    required this.taskId,
    this.fromStatus,
    required this.toStatus,
    this.message,
    this.changedBy,
    this.changedAt,
    this.changedByName,
  });

  factory TaskStatusHistoryEntry.fromJson(Map<String, dynamic> json) => TaskStatusHistoryEntry(
        id: asInt(json['id']),
        taskId: asInt(json['task_id']),
        fromStatus: asStringOrNull(json['from_status']),
        toStatus: asString(json['to_status']),
        message: asStringOrNull(json['message']),
        changedBy: asIntOrNull(json['changed_by']),
        changedAt: asStringOrNull(json['changed_at']),
        changedByName: asStringOrNull(json['changed_by_name']),
      );
}
