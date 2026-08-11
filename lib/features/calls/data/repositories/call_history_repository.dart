import '../../domain/models/call_history_item.dart';

abstract class CallHistoryRepository {
  Future<List<CallHistoryItem>> loadHistory();
  Stream<List<CallHistoryItem>> watchHistory();

  Future<String?> logCall({
    required String callerId,
    required String receiverId,
    required CallType type,
    required CallDirection direction,
    required List<String> participantIds,
  });

  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    DateTime? endedAt,
    int? durationSeconds,
  });

  Future<void> addParticipants({
    required String callId,
    required List<String> agentIds,
  });
}

class EmptyCallHistoryRepository implements CallHistoryRepository {
  @override
  Future<List<CallHistoryItem>> loadHistory() async {
    return const [];
  }

  @override
  Stream<List<CallHistoryItem>> watchHistory() {
    return Stream.value(const []);
  }

  @override
  Future<String?> logCall({
    required String callerId,
    required String receiverId,
    required CallType type,
    required CallDirection direction,
    required List<String> participantIds,
  }) async {
    return null;
  }

  @override
  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {}

  @override
  Future<void> addParticipants({
    required String callId,
    required List<String> agentIds,
  }) async {}
}
