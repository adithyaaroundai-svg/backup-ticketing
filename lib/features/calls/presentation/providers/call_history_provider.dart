import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/call_history_repository.dart';
import '../../domain/models/call_history_item.dart';

final callHistoryRepositoryProvider = Provider<CallHistoryRepository>((ref) {
  // Currently returning EmptyCallHistoryRepository as per Phase 1
  return EmptyCallHistoryRepository();
});

class CallHistorySearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String value) {
    state = value;
  }
}

final callHistorySearchQueryProvider = NotifierProvider<CallHistorySearchQuery, String>(
  CallHistorySearchQuery.new,
);

class CallHistoryController extends AsyncNotifier<List<CallHistoryItem>> {
  @override
  Future<List<CallHistoryItem>> build() async {
    final repo = ref.watch(callHistoryRepositoryProvider);
    return await repo.loadHistory();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(callHistoryRepositoryProvider);
      return await repo.loadHistory();
    });
  }
}

final callHistoryControllerProvider =
    AsyncNotifierProvider<CallHistoryController, List<CallHistoryItem>>(
        CallHistoryController.new);

final filteredCallHistoryProvider = Provider<List<CallHistoryItem>>((ref) {
  final historyResult = ref.watch(callHistoryControllerProvider);
  final searchQuery = ref.watch(callHistorySearchQueryProvider).toLowerCase();

  return historyResult.maybeWhen(
    data: (history) {
      if (searchQuery.isEmpty) return history;

      return history.where((call) {
        final matchesCaller = call.callerName.toLowerCase().contains(searchQuery);
        final matchesReceiver = call.receiverName.toLowerCase().contains(searchQuery);
        // We can also format date and status here, but for now simple matches
        final matchesStatus = call.status.name.toLowerCase().contains(searchQuery);
        return matchesCaller || matchesReceiver || matchesStatus;
      }).toList();
    },
    orElse: () => [],
  );
});
