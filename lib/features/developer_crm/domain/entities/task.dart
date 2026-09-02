import '../../core/parse_utils.dart';
import '../../core/time_utils.dart';

/// An assignee reference. On board/client-detail task shapes this is
/// `{id, name}`; on the full-detail task shape (`GET /api/tasks/:id`)
/// `assignees` is just a bare list of user-id numbers, so `name` is null.
class AssigneeRef {
  final int id;
  final String? name;

  AssigneeRef({required this.id, this.name});
}

/// A task file. Board rows carry `{id, filename}`; full-detail/client-detail
/// rows carry the full `task_files` row.
class TaskFile {
  final int id;
  final int? taskId;
  final String filename;
  final String? storagePath;
  final String? uploadedAt;

  TaskFile({
    required this.id,
    this.taskId,
    required this.filename,
    this.storagePath,
    this.uploadedAt,
  });

  factory TaskFile.fromJson(Map<String, dynamic> json) => TaskFile(
        id: asInt(json['id']),
        taskId: asIntOrNull(json['task_id']),
        filename: asString(json['filename']),
        storagePath: asStringOrNull(json['storage_path']),
        uploadedAt: asStringOrNull(json['uploaded_at']),
      );
}

class Task {
  final int id;
  final int? clientId;
  final String? client;
  final int? projectId;
  final String description;
  final String priority;
  final bool approved;
  final String status;
  final String? expectedFinish;
  final String? startDate;
  final String? taskDate;
  final String? completedAt;
  final String? cancelReason;
  final int? createdBy;
  final String? createdByName;
  final int? statusUpdatedBy;
  final String? statusUpdatedByName;
  final String? statusUpdatedAt;
  final String? lastStatusMessage;
  final bool pending;
  final num? billAmount;
  final bool billed;
  final int timeSpentSeconds;
  final String? timerStartedAt;
  final String? createdAt;
  final num advancesTotal;
  final List<AssigneeRef> assignees;
  final List<TaskFile> files;

  Task({
    required this.id,
    this.clientId,
    this.client,
    this.projectId,
    required this.description,
    required this.priority,
    required this.approved,
    required this.status,
    this.expectedFinish,
    this.startDate,
    this.taskDate,
    this.completedAt,
    this.cancelReason,
    this.createdBy,
    this.createdByName,
    this.statusUpdatedBy,
    this.statusUpdatedByName,
    this.statusUpdatedAt,
    this.lastStatusMessage,
    required this.pending,
    this.billAmount,
    required this.billed,
    required this.timeSpentSeconds,
    this.timerStartedAt,
    this.createdAt,
    this.advancesTotal = 0,
    this.assignees = const [],
    this.files = const [],
  });

  bool get isWorking => status == 'working';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Live elapsed seconds: if the timer is running (status == working and
  /// timer_started_at set), add the elapsed wall-clock time since then to
  /// the stored base. Mirrors the original EJS client-side computation.
  int liveSeconds({DateTime? now}) {
    return computeLiveSeconds(
      base: timeSpentSeconds,
      running: isWorking,
      timerStartedAt: timerStartedAt,
      now: now,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawAssignees = json['assignees'];
    final assignees = <AssigneeRef>[];
    if (rawAssignees is List) {
      for (final a in rawAssignees) {
        if (a is Map) {
          assignees.add(AssigneeRef(id: asInt(a['id']), name: asStringOrNull(a['name'])));
        } else {
          assignees.add(AssigneeRef(id: asInt(a)));
        }
      }
    }
    final rawFiles = json['files'];
    final files = <TaskFile>[];
    if (rawFiles is List) {
      for (final f in rawFiles) {
        if (f is Map) files.add(TaskFile.fromJson(Map<String, dynamic>.from(f)));
      }
    }
    return Task(
      id: asInt(json['id']),
      clientId: asIntOrNull(json['client_id']),
      client: asStringOrNull(json['client']),
      projectId: asIntOrNull(json['project_id']),
      description: asString(json['description']),
      priority: asString(json['priority'], 'A'),
      approved: asBool(json['approved']),
      status: asString(json['status'], 'not_started'),
      expectedFinish: asStringOrNull(json['expected_finish']),
      startDate: asStringOrNull(json['start_date']),
      taskDate: asStringOrNull(json['task_date']),
      completedAt: asStringOrNull(json['completed_at']),
      cancelReason: asStringOrNull(json['cancel_reason']),
      createdBy: asIntOrNull(json['created_by']),
      createdByName: asStringOrNull(json['created_by_name']),
      statusUpdatedBy: asIntOrNull(json['status_updated_by']),
      statusUpdatedByName: asStringOrNull(json['status_updated_by_name']),
      statusUpdatedAt: asStringOrNull(json['status_updated_at']),
      lastStatusMessage: asStringOrNull(json['last_status_message']),
      pending: asBool(json['pending']),
      billAmount: asNumOrNull(json['bill_amount']),
      billed: asBool(json['billed']),
      timeSpentSeconds: asInt(json['time_spent_seconds']),
      timerStartedAt: asStringOrNull(json['timer_started_at']),
      createdAt: asStringOrNull(json['created_at']),
      advancesTotal: asNum(json['advances_total']),
      assignees: assignees,
      files: files,
    );
  }
}
