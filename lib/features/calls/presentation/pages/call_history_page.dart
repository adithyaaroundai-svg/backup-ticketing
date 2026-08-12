import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/layout/main_layout.dart';
import '../../../../core/services/zoho_launcher.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../domain/models/call_history_item.dart';
import '../providers/call_history_provider.dart';

class CallHistoryPage extends ConsumerWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return MainLayout(
      currentPath: GoRouterState.of(context).uri.toString(),
      child: isMobile ? const _MobileCallHistory() : const _DesktopCallHistory(),
    );
  }
}

class _DesktopCallHistory extends ConsumerWidget {
  const _DesktopCallHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final bgColor = isLight ? AppColors.slate50 : AppColors.slate900;
    final borderColor = isLight ? AppColors.slate200 : AppColors.slate700;

    return Row(
      children: [
        // Left Panel
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Calls',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  onChanged: (value) {
                    ref.read(callHistorySearchQueryProvider.notifier).updateQuery(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search people, status...',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    filled: true,
                    fillColor: isLight ? Colors.white : AppColors.slate800,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Recent contacts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isLight ? AppColors.slate600 : AppColors.slate400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: _RecentContactsList(),
              ),
            ],
          ),
        ),
        // Right Panel
        const Expanded(
          child: _CallHistoryList(),
        ),
      ],
    );
  }
}

class _MobileCallHistory extends ConsumerWidget {
  const _MobileCallHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            onChanged: (value) {
              ref.read(callHistorySearchQueryProvider.notifier).updateQuery(value);
            },
            decoration: InputDecoration(
              hintText: 'Search people...',
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const Expanded(
          child: _CallHistoryList(),
        ),
      ],
    );
  }
}

class _RecentContactsList extends ConsumerWidget {
  const _RecentContactsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyResult = ref.watch(callHistoryControllerProvider);
    final myId = ref.watch(authProvider)?.id ?? '';

    return historyResult.when(
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        
        final recentContacts = <String, CallHistoryItem>{};
        for (var call in history) {
          final isIncoming = call.receiverId == myId;
          final partnerId = isIncoming ? call.callerId : call.receiverId;
          if (partnerId.isNotEmpty && !recentContacts.containsKey(partnerId)) {
            recentContacts[partnerId] = call;
          }
        }

        final contactsList = recentContacts.values.toList();
        if (contactsList.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          itemCount: contactsList.length,
          itemBuilder: (context, index) {
            final call = contactsList[index];
            final isIncoming = call.receiverId == myId;
            final partnerName = isIncoming ? call.callerName : call.receiverName;
            final avatarUrl = call.avatarUrl;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? Text(partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?') : null,
              ),
              title: Text(
                partnerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // Focus search on this contact
                ref.read(callHistorySearchQueryProvider.notifier).updateQuery(partnerName);
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading contacts')),
    );
  }
}

class _CallHistoryList extends ConsumerWidget {
  const _CallHistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryControllerProvider);
    final filteredHistory = ref.watch(filteredCallHistoryProvider);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final myId = ref.watch(authProvider)?.id ?? '';

    return Container(
      color: isLight ? Colors.white : AppColors.slate900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'History',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(callHistoryControllerProvider.notifier).refresh(),
              child: historyAsync.when(
                data: (_) {
                  if (filteredHistory.isEmpty) {
                    return _EmptyState();
                  }

                  return ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final call = filteredHistory[index];
                      return _CallHistoryRow(call: call, myId: myId);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error loading calls: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.phone,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Call History',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your previous voice and video calls will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallHistoryRow extends ConsumerWidget {
  final CallHistoryItem call;
  final String myId;

  const _CallHistoryRow({required this.call, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncoming = call.receiverId == myId;
    final partnerName = isIncoming ? call.callerName : call.receiverName;
    final partnerId = isIncoming ? call.callerId : call.receiverId;
    final avatarUrl = call.avatarUrl;

    // Status icon
    IconData statusIcon;
    Color statusColor;
    if (call.status == CallStatus.missed || call.status == CallStatus.rejected) {
      statusIcon = isIncoming ? LucideIcons.phoneIncoming : LucideIcons.phoneOutgoing;
      statusColor = AppColors.error;
    } else {
      statusIcon = isIncoming ? LucideIcons.phoneIncoming : LucideIcons.phoneOutgoing;
      statusColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Type icon
    final typeIcon = call.callType == CallType.video ? LucideIcons.video : LucideIcons.phone;

    // Format duration
    String durationText = '';
    if (call.duration != null && call.duration!.inSeconds > 0) {
      final m = call.duration!.inMinutes;
      final s = call.duration!.inSeconds % 60;
      if (m > 0) {
        durationText = '${m}m ${s}s';
      } else {
        durationText = '${s}s';
      }
    } else if (call.status == CallStatus.missed) {
      durationText = 'Missed';
    } else if (call.status == CallStatus.rejected) {
      durationText = 'Rejected';
    } else if (call.status == CallStatus.cancelled) {
      durationText = 'Cancelled';
    }

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Text(partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?') : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        _getCallDescription(call, isIncoming),
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Right info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('MMM d, h:mm a').format(call.startedAt.toLocal()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(call.startedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (durationText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    durationText,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 24),
            
            // Call action
            IconButton(
              icon: Icon(typeIcon, color: theme.primaryColor),
              onPressed: () => _handleCallAgain(context, ref, call),
              tooltip: 'Call Again',
            ),
          ],
        ),
      ),
    );
  }

  String _getCallDescription(CallHistoryItem call, bool isIncoming) {
    final direction = isIncoming ? 'Incoming' : 'Outgoing';
    final type = call.callType == CallType.video ? 'Video' : 'Voice';
    if (call.status == CallStatus.missed) return 'Missed Call';
    if (call.status == CallStatus.rejected) return 'Rejected Call';
    if (call.status == CallStatus.cancelled) return 'Cancelled Call';
    return '$direction $type Call';
  }

  Future<void> _handleCallAgain(BuildContext context, WidgetRef ref, CallHistoryItem call) async {
    final agentsAsync = ref.read(agentsListProvider);
    final agents = agentsAsync.value ?? [];
    final currentUser = ref.read(authProvider);

    if (currentUser == null) return;

    final participantIds = call.participants.map((p) => p.agentId).toSet().toList();
    if (participantIds.isEmpty) {
      // Fallback if participants are not populated in older records
      participantIds.add(call.callerId);
      if (call.callerId != call.receiverId) {
        participantIds.add(call.receiverId);
      }
    }

    final targetIds = participantIds.where((id) => id != currentUser.id).toList();

    String? targetZohoId;
    for (final agent in agents) {
      if (targetIds.contains(agent['id'])) {
        final zohoId = agent['zoho_mail_id'] as String?;
        if (zohoId != null && zohoId.trim().isNotEmpty) {
          targetZohoId = zohoId;
          break;
        }
      }
    }

    if (targetZohoId == null || targetZohoId.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent has no Zoho Cliq ID configured.')),
        );
      }
      return;
    }

    try {
      final repo = ref.read(callHistoryRepositoryProvider);
      
      final receiverId = targetIds.isNotEmpty ? targetIds.first : currentUser.id;
      
      // We must make sure current user is in participants list
      final Set<String> finalParticipantIds = {...targetIds, currentUser.id};

      await repo.logCall(
        callerId: currentUser.id,
        receiverId: receiverId,
        type: call.callType,
        direction: CallDirection.outgoing,
        participantIds: finalParticipantIds.toList(),
      );
    } catch (e, st) {
      debugPrint('Failed to log call history: $e');
    }

    await launchZohoCliqUser(targetZohoId.trim());
  }
}
