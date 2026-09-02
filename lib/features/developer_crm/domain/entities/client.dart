import '../../core/parse_utils.dart';

class Client {
  final int id;
  final String name;
  final String? contact;
  final String? createdAt;
  // Only present on GET /api/clients (list endpoint):
  final String? openCount;
  final bool? ongoing;
  final String? lastActivity;

  Client({
    required this.id,
    required this.name,
    this.contact,
    this.createdAt,
    this.openCount,
    this.ongoing,
    this.lastActivity,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: asInt(json['id']),
        name: asString(json['name']),
        contact: asStringOrNull(json['contact']),
        createdAt: asStringOrNull(json['created_at']),
        openCount: asStringOrNull(json['open_count']),
        ongoing: json.containsKey('ongoing') ? asBool(json['ongoing']) : null,
        lastActivity: asStringOrNull(json['last_activity']),
      );
}
