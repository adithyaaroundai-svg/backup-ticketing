import '../../core/parse_utils.dart';
import '../../core/time_utils.dart';

class TeamTaskRow {
  final int userId;
  final int id;
  final String description;
  final String status;
  final int timeSpentSeconds;
  final String? timerStartedAt;
  final int? clientId;
  final String? client;
  final int seconds;
  final bool running;

  TeamTaskRow({
    required this.userId,
    required this.id,
    required this.description,
    required this.status,
    required this.timeSpentSeconds,
    this.timerStartedAt,
    this.clientId,
    this.client,
    required this.seconds,
    required this.running,
  });

  /// Live elapsed seconds, ticking continuously client-side while
  /// `running`, using the same base+timer_started_at formula as [Task].
  int liveSeconds({DateTime? now}) => computeLiveSeconds(
        base: timeSpentSeconds,
        running: running,
        timerStartedAt: timerStartedAt,
        now: now,
      );

  factory TeamTaskRow.fromJson(Map<String, dynamic> json) => TeamTaskRow(
        userId: asInt(json['user_id']),
        id: asInt(json['id']),
        description: asString(json['description']),
        status: asString(json['status']),
        timeSpentSeconds: asInt(json['time_spent_seconds']),
        timerStartedAt: asStringOrNull(json['timer_started_at']),
        clientId: asIntOrNull(json['client_id']),
        client: asStringOrNull(json['client']),
        seconds: asInt(json['seconds']),
        running: asBool(json['running']),
      );
}

class TeamMemberRow {
  final int id;
  final String name;
  final String role;
  final int total;
  final List<TeamTaskRow> tasks;

  TeamMemberRow({
    required this.id,
    required this.name,
    required this.role,
    required this.total,
    required this.tasks,
  });

  factory TeamMemberRow.fromJson(Map<String, dynamic> json) => TeamMemberRow(
        id: asInt(json['id']),
        name: asString(json['name']),
        role: asString(json['role']),
        total: asInt(json['total']),
        tasks: (json['tasks'] as List? ?? [])
            .map((e) => TeamTaskRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
