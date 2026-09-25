import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/leave_request.dart';
import '../providers/leave_provider.dart';
import 'apply_leave_dialog.dart';

class EmployeeLeavesDialog extends ConsumerWidget {
  final String agentId;
  final String agentName;
  final String agentRole;
  final String? email;

  const EmployeeLeavesDialog({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.agentRole,
    this.email,
  });

  static Future<void> show(
    BuildContext context, {
    required String agentId,
    required String agentName,
    required String agentRole,
    String? email,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EmployeeLeavesDialog(
        agentId: agentId,
        agentName: agentName,
        agentRole: agentRole,
        email: email,
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, LeaveRequest leave, Agent hrAgent) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reject Leave Request', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject leave for ${leave.agentName} (${leave.dateRangeFormatted})?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Optional rejection reason...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(leaveControllerProvider.notifier).rejectLeave(
                    leave: leave,
                    hrAgent: hrAgent,
                    rejectionReason: reasonController.text.trim(),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(agentLeavesFamilyProvider(agentId));
    final currentUser = ref.watch(authProvider);
    final isHR = currentUser?.isHR == true || currentUser?.isAdmin == true;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(LucideIcons.user, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$agentName — Leave Records',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$agentRole • ${email ?? "Employee"}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ApplyLeaveDialog.show(
                        context,
                        targetAgentId: agentId,
                        targetAgentName: agentName,
                        targetAgentRole: agentRole,
                      );
                    },
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Apply Leave'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 28),

              // Leaves List
              Expanded(
                child: leavesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error loading leaves: $err', style: const TextStyle(color: AppColors.error)),
                  ),
                  data: (leaves) {
                    if (leaves.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.calendarX, size: 48, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text(
                              'No leave requests found for this employee',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                ApplyLeaveDialog.show(
                                  context,
                                  targetAgentId: agentId,
                                  targetAgentName: agentName,
                                  targetAgentRole: agentRole,
                                );
                              },
                              icon: const Icon(LucideIcons.calendarPlus, size: 16),
                              label: const Text('Apply Leave for Employee'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final totalDaysApproved = leaves
                        .where((l) => l.isApproved)
                        .fold<int>(0, (sum, l) => sum + l.totalDays);
                    final pendingCount = leaves.where((l) => l.isPending).length;

                    return Column(
                      children: [
                        // Summary metrics row
                        Row(
                          children: [
                            _MetricBadge(
                              label: 'Total Approved Leaves',
                              value: '$totalDaysApproved days',
                              color: AppColors.success,
                              icon: LucideIcons.calendarCheck,
                            ),
                            const SizedBox(width: 12),
                            _MetricBadge(
                              label: 'Pending Requests',
                              value: '$pendingCount',
                              color: Colors.amber,
                              icon: LucideIcons.clock,
                            ),
                            const SizedBox(width: 12),
                            _MetricBadge(
                              label: 'Total Requests',
                              value: '${leaves.length}',
                              color: AppColors.primary,
                              icon: LucideIcons.fileText,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // List of leaves
                        Expanded(
                          child: ListView.separated(
                            itemCount: leaves.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final leave = leaves[index];
                              return _LeaveRowCard(
                                leave: leave,
                                isHR: isHR,
                                onApprove: isHR && leave.isPending && currentUser != null
                                    ? () => ref.read(leaveControllerProvider.notifier).approveLeave(
                                          leave: leave,
                                          hrAgent: currentUser,
                                        )
                                    : null,
                                onReject: isHR && leave.isPending && currentUser != null
                                    ? () => _showRejectDialog(context, ref, leave, currentUser)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveRowCard extends StatelessWidget {
  final LeaveRequest leave;
  final bool isHR;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _LeaveRowCard({
    required this.leave,
    required this.isHR,
    this.onApprove,
    this.onReject,
  });

  Color get _statusColor {
    if (leave.isApproved) return AppColors.success;
    if (leave.isRejected) return AppColors.error;
    if (leave.isCancelled) return Colors.grey;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leave Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              leave.isApproved
                  ? LucideIcons.calendarCheck
                  : leave.isRejected
                      ? LucideIcons.calendarX
                      : LucideIcons.calendarClock,
              color: _statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      leave.dateRangeFormatted,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${leave.leaveType} (${leave.totalDays} ${leave.totalDays == 1 ? "day" : "days"})',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    leave.reason!,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Requested on ${fmt.format(leave.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                    if (leave.isApproved && leave.approvedByName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Approved by ${leave.approvedByName}',
                        style: const TextStyle(fontSize: 11, color: AppColors.success),
                      ),
                    ],
                    if (leave.isRejected && leave.rejectionReason != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Rejected: "${leave.rejectionReason}"',
                        style: const TextStyle(fontSize: 11, color: AppColors.error),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Status & HR Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  leave.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
              if (onApprove != null || onReject != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onApprove != null)
                      IconButton(
                        onPressed: onApprove,
                        icon: const Icon(LucideIcons.check, color: AppColors.success, size: 18),
                        tooltip: 'Approve',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.success.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    if (onReject != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: onReject,
                        icon: const Icon(LucideIcons.x, color: AppColors.error, size: 18),
                        tooltip: 'Reject',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
