import '../../core/parse_utils.dart';

class Advance {
  final int id;
  final int taskId;
  final num amount;
  final String? note;
  final int? createdBy;
  final String? createdAt;
  final String? createdByName;

  Advance({
    required this.id,
    required this.taskId,
    required this.amount,
    this.note,
    this.createdBy,
    this.createdAt,
    this.createdByName,
  });

  factory Advance.fromJson(Map<String, dynamic> json) => Advance(
        id: asInt(json['id']),
        taskId: asInt(json['task_id']),
        amount: asNum(json['amount']),
        note: asStringOrNull(json['note']),
        createdBy: asIntOrNull(json['created_by']),
        createdAt: asStringOrNull(json['created_at']),
        createdByName: asStringOrNull(json['created_by_name']),
      );
}
