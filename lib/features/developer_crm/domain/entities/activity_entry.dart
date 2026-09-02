import '../../core/parse_utils.dart';

class ActivityEntry {
  final int id;
  final int? userId;
  final String? userName;
  final String message;
  final String? createdAt;

  ActivityEntry({
    required this.id,
    this.userId,
    this.userName,
    required this.message,
    this.createdAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: asInt(json['id']),
        userId: asIntOrNull(json['user_id']),
        userName: asStringOrNull(json['user_name']),
        message: asString(json['message']),
        createdAt: asStringOrNull(json['created_at']),
      );
}
