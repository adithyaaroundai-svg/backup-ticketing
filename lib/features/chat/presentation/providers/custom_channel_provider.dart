import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/custom_channel.dart';
import '../../data/repositories/custom_channel_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

class CustomChannelsNotifier extends AsyncNotifier<List<CustomChannel>> {
  @override
  FutureOr<List<CustomChannel>> build() async {
    final repository = ref.watch(customChannelRepositoryProvider);
    final currentUser = ref.watch(authProvider);
    final currentUserId = currentUser?.id ?? '';
    if (currentUserId.isEmpty) return [];
    return repository.getChannels(currentUserId);
  }

  Future<void> fetchChannels() async {
    final repository = ref.read(customChannelRepositoryProvider);
    final currentUser = ref.read(authProvider);
    final currentUserId = currentUser?.id ?? '';
    if (currentUserId.isEmpty) return;
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.getChannels(currentUserId));
  }

  Future<CustomChannel?> createChannel({
    required String name,
    required bool isPrivate,
    required String createdBy,
    required List<String> memberIds,
  }) async {
    try {
      final repository = ref.read(customChannelRepositoryProvider);
      final newChannel = await repository.createChannel(
        name: name,
        isPrivate: isPrivate,
        createdBy: createdBy,
        memberIds: memberIds,
      );
      
      // Update local state
      if (state.hasValue) {
        state = AsyncValue.data([...state.value!, newChannel]);
      }
      return newChannel;
    } catch (e, st) {
      print('Error creating channel: $e');
      print('Stack trace: $st');
      return null;
    }
  }

  Future<bool> deleteChannel(String channelId, String currentUserId) async {
    try {
      final repository = ref.read(customChannelRepositoryProvider);
      await repository.deleteChannel(channelId, currentUserId);

      // Update local state
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.where((c) => c.id != channelId).toList(),
        );
      }
      return true;
    } catch (e, st) {
      print('Error deleting channel: $e');
      print('Stack trace: $st');
      rethrow;
    }
  }
}

final customChannelsProvider = AsyncNotifierProvider<CustomChannelsNotifier, List<CustomChannel>>(() {
  return CustomChannelsNotifier();
});
