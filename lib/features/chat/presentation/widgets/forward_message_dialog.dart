import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/design_system/design_system.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ForwardMessageDialog extends ConsumerStatefulWidget {
  final ChatMessage message;

  const ForwardMessageDialog({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  ConsumerState<ForwardMessageDialog> createState() => _ForwardMessageDialogState();
}

class _ForwardMessageDialogState extends ConsumerState<ForwardMessageDialog> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  bool _isSending = false;

  final List<Map<String, String>> _groupChannels = [
    {'id': 'support-chat', 'name': 'Global Chat', 'type': 'group'},
    {'id': 'sales-channel', 'name': 'Sales Chat', 'type': 'group'},
    {'id': 'all-aroundtally', 'name': 'All Aroundtally', 'type': 'group'},
  ];

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(agentsListProvider);
    final currentUser = ref.watch(authProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Forward Message',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.adaptiveSlate900,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.adaptiveSlate500),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search Box
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search chats or agents...',
                prefixIcon: Icon(Icons.search, size: 18, color: context.adaptiveSlate400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.adaptiveBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.adaptiveBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: agentsAsync.when(
                data: (agents) {
                  // Filter agents
                  final filteredAgents = agents.where((agent) {
                    final name = (agent['full_name'] ?? agent['username'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) && agent['id'] != currentUser?.id;
                  }).toList();

                  // Filter groups
                  final filteredGroups = _groupChannels.where((group) {
                    return group['name']!.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filteredAgents.isEmpty && filteredGroups.isEmpty) {
                    return const Center(child: Text('No results found.'));
                  }

                  return ListView(
                    children: [
                      if (filteredGroups.isNotEmpty) ...[
                        _buildSectionHeader('Group Channels'),
                        ...filteredGroups.map((group) => _buildListItem(
                          id: group['id']!,
                          name: group['name']!,
                          type: 'group',
                        )),
                      ],
                      if (filteredAgents.isNotEmpty) ...[
                        _buildSectionHeader('Agents'),
                        ...filteredAgents.map((agent) => _buildListItem(
                          id: agent['id'] as String,
                          name: agent['full_name'] ?? agent['username'] ?? 'Unknown Agent',
                          type: 'dm',
                          avatarUrl: agent['avatar_url'],
                        )),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading agents: $e')),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: context.adaptiveSlate600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _selectedIds.isEmpty || _isSending ? null : _forwardMessage,
                  icon: _isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text('Send', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.adaptiveSlate500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListItem({
    required String id,
    required String name,
    required String type,
    String? avatarUrl,
  }) {
    // For groups, id is the channel name. For DMs, id is the user ID.
    final combinedId = '${type}_$id';
    final isSelected = _selectedIds.contains(combinedId);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(combinedId);
          } else {
            _selectedIds.add(combinedId);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: type == 'group' ? AppColors.slate200 : AppColors.primary.withOpacity(0.2),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Icon(
                      type == 'group' ? Icons.tag : Icons.person,
                      size: 16,
                      color: type == 'group' ? AppColors.slate600 : AppColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: context.adaptiveSlate900,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            else
              Icon(Icons.circle_outlined, color: context.adaptiveSlate300, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _forwardMessage() async {
    final currentUser = ref.read(authProvider);
    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      final chatController = ref.read(chatControllerProvider.notifier);
      final forwardedContent = widget.message.content;

      for (final selectedId in _selectedIds) {
        if (selectedId.startsWith('group_')) {
          final channelId = selectedId.substring(6);
          await chatController.sendMessage(
            senderId: currentUser.id,
            senderName: currentUser.fullName ?? currentUser.username ?? 'Agent',
            senderRole: currentUser.role ?? 'agent',
            senderAvatarUrl: currentUser.avatarUrl,
            content: forwardedContent,
            channel: channelId,
            fileUrl: widget.message.fileUrl,
            fileName: widget.message.fileName,
            fileType: widget.message.fileType,
            isForwarded: true,
          );
        } else if (selectedId.startsWith('dm_')) {
          final receiverId = selectedId.substring(3);
          final uid1 = currentUser.id;
          final uid2 = receiverId;
          
          // Generate DM channel ID
          final sortedIds = [uid1, uid2]..sort();
          final dmChannelId = 'dm_${sortedIds[0]}_${sortedIds[1]}';
          
          await chatController.sendMessage(
            senderId: currentUser.id,
            receiverId: receiverId,
            senderName: currentUser.fullName ?? currentUser.username ?? 'Agent',
            senderRole: currentUser.role ?? 'agent',
            senderAvatarUrl: currentUser.avatarUrl,
            content: forwardedContent,
            channel: dmChannelId,
            fileUrl: widget.message.fileUrl,
            fileName: widget.message.fileName,
            fileType: widget.message.fileType,
            isForwarded: true,
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message forwarded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error forwarding message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
