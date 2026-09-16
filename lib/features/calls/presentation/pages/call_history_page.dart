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
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: isLight ? Colors.white : AppColors.slate900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 24.0,
              vertical: isMobile ? 12.0 : 24.0,
            ),
            child: Text(
              'History',
              style: (isMobile ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(callHistoryControllerProvider.notifier).refresh(),
              child: historyAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isIncoming = call.receiverId == myId;
    final partnerName = isIncoming ? call.callerName : call.receiverName;
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
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12.0 : 20.0,
          vertical: isMobile ? 8.0 : 12.0,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: isMobile ? 18 : 22,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: isMobile ? 14 : 16),
                    )
                  : null,
            ),
            SizedBox(width: isMobile ? 10 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(statusIcon, size: isMobile ? 12 : 14, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _getCallDescription(call, isIncoming),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 13,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('MMM d, h:mm a').format(call.startedAt.toLocal()),
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(call.startedAt),
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (durationText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    durationText,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(width: isMobile ? 2 : 12),

            // Call action
            IconButton(
              icon: Icon(typeIcon, size: isMobile ? 18 : 22, color: theme.primaryColor),
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              constraints: const BoxConstraints(),
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
    } catch (e) {
      debugPrint('Failed to log call history: $e');
    }

    await launchZohoCliqUser(targetZohoId.trim());
  }
}
