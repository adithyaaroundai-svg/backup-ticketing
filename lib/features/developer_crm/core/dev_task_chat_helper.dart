import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'enums.dart';

/// Broadcasts a developer task status change into the Software Development channel
Future<void> postDevTaskStatusChangeToSoftwareDevChannel({
  required int taskId,
  String? oldStatus,
  required String newStatus,
  String? taskDescription,
  String? clientName,
  int? clientId,
  int? currentUserId,
  String? currentUserName,
  String? statusMessage,
}) async {
  try {
    final supabase = Supabase.instance.client;

    // 1. Look for Software Development channel in custom_channels
    final channels = await supabase
        .from('custom_channels')
        .select('id, name')
        .order('created_at', ascending: true);

    String? devChannelId;
    for (final ch in channels as List) {
      final name = (ch['name'] ?? '').toString().toLowerCase().replaceAll('-', ' ').replaceAll('_', ' ').trim();
      if (name.contains('software dev') || name.contains('software development') || name.contains('development')) {
        devChannelId = ch['id']?.toString();
        break;
      }
    }

    if (devChannelId == null && channels.isNotEmpty) {
      for (final ch in channels) {
        final name = (ch['name'] ?? '').toString().toLowerCase();
        if (name.contains('dev') || name.contains('software')) {
          devChannelId = ch['id']?.toString();
          break;
        }
      }
    }

    if (devChannelId == null) return;

    // 2. Fetch client name and description if missing
    String cName = clientName ?? '';
    String desc = taskDescription ?? '';

    if (cName.isEmpty || desc.isEmpty) {
      try {
        final taskData = await supabase
            .schema('aroundtally')
            .from('tasks')
            .select('description, client_id, clients(name)')
            .eq('id', taskId)
            .maybeSingle();

        if (taskData != null) {
          if (desc.isEmpty) desc = (taskData['description'] as String?)?.trim() ?? '#$taskId';
          if (cName.isEmpty) {
            final clientObj = taskData['clients'];
            if (clientObj is Map) {
              cName = (clientObj['name'] as String?)?.trim() ?? '';
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching task info for chat: $e');
      }
    }

    if (cName.isEmpty && clientId != null) {
      try {
        final clientData = await supabase
            .schema('aroundtally')
            .from('clients')
            .select('name')
            .eq('id', clientId)
            .maybeSingle();
        if (clientData != null) {
          cName = (clientData['name'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
    }

    if (cName.isEmpty) cName = 'Client';
    if (desc.isEmpty) desc = 'Task #$taskId';

    final formattedOld = (oldStatus != null && oldStatus.isNotEmpty) ? taskStatusLabel(oldStatus) : '';
    final formattedNew = taskStatusLabel(newStatus);
    final statusDisplay = (formattedOld.isNotEmpty && formattedOld != formattedNew)
        ? '$formattedOld ➔ $formattedNew'
        : formattedNew;

    final chatContent = [
      'Company: $cName',
      'Issue: $desc',
      'Status: $statusDisplay',
      'TaskID: #$taskId',
      'DevTaskID: $taskId',
      'TicketID: dev-$taskId',
      if (statusMessage != null && statusMessage.isNotEmpty) 'Note: $statusMessage',
    ].join('\n');

    // Resolve sender
    String senderId = 'system';
    final authUser = supabase.auth.currentUser;
    if (authUser != null) {
      senderId = authUser.id;
    }

    final senderName = (currentUserName != null && currentUserName.isNotEmpty)
        ? currentUserName
        : (authUser?.userMetadata?['full_name'] ?? authUser?.email ?? 'System');

    await supabase.from('chat_messages').insert({
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': 'Software Developer',
      'content': chatContent,
      'channel': devChannelId,
      'is_forwarded': false,
    });
  } catch (e) {
    debugPrint('Error posting dev task status change to software dev channel: $e');
  }
}
