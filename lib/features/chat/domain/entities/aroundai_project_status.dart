class AroundaiProjectStatus {
  final int id;
  final String taskName;
  final String taskStatus;
  final String? notes;
  final String? createdBy; // UUID of creator
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AroundaiProjectStatus({
    required this.id,
    required this.taskName,
    required this.taskStatus,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory AroundaiProjectStatus.fromJson(Map<String, dynamic> json) {
    return AroundaiProjectStatus(
      id: json['id'] as int,
      taskName: json['task_name'] as String,
      taskStatus: json['task_status'] as String,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }
}
