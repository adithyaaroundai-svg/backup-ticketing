import '../../domain/models/call_history_item.dart';

abstract class CallHistoryRepository {
  Future<List<CallHistoryItem>> loadHistory();
  Stream<List<CallHistoryItem>> watchHistory();
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
}
