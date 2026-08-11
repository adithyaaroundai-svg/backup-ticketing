import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/call_history_repository.dart';
import '../../data/repositories/supabase_call_history_repository.dart';
import '../../domain/models/call_history_item.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final callHistoryRepositoryProvider = Provider<CallHistoryRepository>((ref) {
  final currentUserId = ref.watch(authProvider)?.id ?? '';
  return SupabaseCallHistoryRepository(Supabase.instance.client, currentUserId);
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
  StreamSubscription<List<CallHistoryItem>>? _subscription;

  @override
  Future<List<CallHistoryItem>> build() async {
    final repo = ref.watch(callHistoryRepositoryProvider);
    
    _subscription?.cancel();
    _subscription = repo.watchHistory().listen((history) {
      state = AsyncValue.data(history);
    }, onError: (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

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
        final matchesStatus = call.status.name.toLowerCase().contains(searchQuery);
        return matchesCaller || matchesReceiver || matchesStatus;
      }).toList();
    },
    orElse: () => [],
  );
});
