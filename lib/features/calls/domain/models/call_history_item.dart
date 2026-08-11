enum CallDirection { incoming, outgoing }

enum CallType { audio, video }

enum CallStatus { initiated, ringing, answered, missed, rejected, cancelled, ended }

enum CallParticipantRole { caller, participant }

class CallParticipant {
  final String id;
  final String agentId;
  final String agentName;
  final CallParticipantRole role;
  final DateTime? joinedAt;
  final DateTime? leftAt;
  final String? avatarUrl;

  const CallParticipant({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.role,
    this.joinedAt,
    this.leftAt,
    this.avatarUrl,
  });
}

class CallHistoryItem {
  final String id;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final String? avatarUrl;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final CallType callType;
  final CallDirection direction;
  final CallStatus status;
  final List<CallParticipant> participants;

  const CallHistoryItem({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    this.avatarUrl,
    required this.startedAt,
    this.endedAt,
    this.duration,
    required this.callType,
    required this.direction,
    required this.status,
    this.participants = const [],
  });

  CallHistoryItem copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    String? avatarUrl,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    CallType? callType,
    CallDirection? direction,
    CallStatus? status,
    List<CallParticipant>? participants,
  }) {
    return CallHistoryItem(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      participants: participants ?? this.participants,
    );
  }
}
