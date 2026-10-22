import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/leave_request.dart';
import '../providers/leave_provider.dart';
import '../widgets/apply_leave_dialog.dart';

class LeavesPage extends ConsumerStatefulWidget {
  const LeavesPage({super.key});

  @override
  ConsumerState<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends ConsumerState<LeavesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showRejectDialog(LeaveRequest leave, Agent hrAgent) {
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
              'Reject leave request for ${leave.agentName} (${leave.dateRangeFormatted})?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection (visible to employee)...',
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
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isHR = currentUser.isHR == true || currentUser.isAdmin == true;

    return MainLayout(
      currentPath: '/leaves',
      child: Theme(
        data: ThemeData.dark(),
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: isHR ? _buildHRView(currentUser) : _buildEmployeeView(currentUser),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HR / Approver Dashboard View
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHRView(Agent hrUser) {
    final allLeavesAsync = ref.watch(allLeavesStreamProvider);

    return allLeavesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Error loading leaves: $err', style: const TextStyle(color: AppColors.error)),
      ),
      data: (leaves) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final pendingLeaves = leaves.where((l) => l.isPending).toList();
        final approvedLeaves = leaves.where((l) => l.isApproved).toList();
        final rejectedLeaves = leaves.where((l) => l.isRejected).toList();

        // Agents on leave today
        final onLeaveToday = approvedLeaves.where((l) {
          final s = DateTime(l.startDate.year, l.startDate.month, l.startDate.day);
          final e = DateTime(l.endDate.year, l.endDate.month, l.endDate.day);
          return (today.isAfter(s) || today.isAtSameMomentAs(s)) &&
              (today.isBefore(e) || today.isAtSameMomentAs(e));
        }).length;

        // Approved this month
        final approvedThisMonth = approvedLeaves.where((l) {
          return l.startDate.year == now.year && l.startDate.month == now.month;
        }).fold<int>(0, (sum, l) => sum + l.totalDays);

        // Filter by search query
        List<LeaveRequest> filterBySearch(List<LeaveRequest> list) {
          if (_searchQuery.trim().isEmpty) return list;
          final q = _searchQuery.toLowerCase().trim();
          return list.where((l) {
            return l.agentName.toLowerCase().contains(q) ||
                l.agentRole.toLowerCase().contains(q) ||
                l.leaveType.toLowerCase().contains(q) ||
                (l.reason?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        final isMobile = MediaQuery.of(context).size.width <= 768;

        return Column(
          children: [
            // Top Section
            Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                isMobile ? 16 : 24,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  if (isMobile)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/mobile-home');
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leave Register',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'HR Approvals & Records',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => ApplyLeaveDialog.show(context),
                          icon: const Icon(LucideIcons.calendarPlus, size: 14),
                          label: const Text('Apply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Leave Management & Approvals',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Review employee leave requests, approve time off, and track team availability.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => ApplyLeaveDialog.show(context),
                          icon: const Icon(LucideIcons.calendarPlus, size: 16),
                          label: const Text('Apply for Employee'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Metrics Cards
                  if (isMobile)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _StatCard(
                            title: 'Pending Requests',
                            value: '${pendingLeaves.length}',
                            subtitle: 'Requires HR approval',
                            color: Colors.amber,
                            icon: LucideIcons.clock,
                            highlight: pendingLeaves.isNotEmpty,
                            isExpanded: false,
                            width: 190,
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            title: 'On Leave Today',
                            value: '$onLeaveToday',
                            subtitle: 'Approved active leaves',
                            color: Colors.purpleAccent,
                            icon: LucideIcons.plane,
                            isExpanded: false,
                            width: 190,
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            title: 'Approved (This Month)',
                            value: '$approvedThisMonth days',
                            subtitle: 'Across all departments',
                            color: AppColors.success,
                            icon: LucideIcons.calendarCheck,
                            isExpanded: false,
                            width: 190,
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            title: 'Total Applications',
                            value: '${leaves.length}',
                            subtitle: 'Historical records',
                            color: AppColors.primary,
                            icon: LucideIcons.fileSpreadsheet,
                            isExpanded: false,
                            width: 190,
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        _StatCard(
                          title: 'Pending Requests',
                          value: '${pendingLeaves.length}',
                          subtitle: 'Requires HR approval',
                          color: Colors.amber,
                          icon: LucideIcons.clock,
                          highlight: pendingLeaves.isNotEmpty,
                        ),
                        const SizedBox(width: 14),
                        _StatCard(
                          title: 'On Leave Today',
                          value: '$onLeaveToday',
                          subtitle: 'Approved active leaves',
                          color: Colors.purpleAccent,
                          icon: LucideIcons.plane,
                        ),
                        const SizedBox(width: 14),
                        _StatCard(
                          title: 'Approved (This Month)',
                          value: '$approvedThisMonth days',
                          subtitle: 'Across all departments',
                          color: AppColors.success,
                          icon: LucideIcons.calendarCheck,
                        ),
                        const SizedBox(width: 14),
                        _StatCard(
                          title: 'Total Applications',
                          value: '${leaves.length}',
                          subtitle: 'Historical records',
                          color: AppColors.primary,
                          icon: LucideIcons.fileSpreadsheet,
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Search & Tab Bar
                  if (isMobile) ...[
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search employee, role, reason...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white54),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Pending Approvals'),
                                if (pendingLeaves.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${pendingLeaves.length}',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Tab(text: 'Approved (${approvedLeaves.length})'),
                          Tab(text: 'Rejected (${rejectedLeaves.length})'),
                          Tab(text: 'All Requests (${leaves.length})'),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: AppColors.primary,
                              indicatorWeight: 3,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white54,
                              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Pending Approvals'),
                                      if (pendingLeaves.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${pendingLeaves.length}',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Tab(text: 'Approved (${approvedLeaves.length})'),
                                Tab(text: 'Rejected (${rejectedLeaves.length})'),
                                Tab(text: 'All Requests (${leaves.length})'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search employee, role...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              prefixIcon: const Icon(LucideIcons.search, size: 16, color: Colors.white54),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaveList(filterBySearch(pendingLeaves), hrUser, isHR: true),
                  _buildLeaveList(filterBySearch(approvedLeaves), hrUser, isHR: true),
                  _buildLeaveList(filterBySearch(rejectedLeaves), hrUser, isHR: true),
                  _buildLeaveList(filterBySearch(leaves), hrUser, isHR: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Regular Employee View (My Leaves)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEmployeeView(Agent employee) {
    final myLeavesAsync = ref.watch(myLeavesStreamProvider);

    return myLeavesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text('Error loading leaves: $err', style: const TextStyle(color: AppColors.error)),
      ),
      data: (leaves) {
        final pending = leaves.where((l) => l.isPending).length;
        final approvedDays = leaves
            .where((l) => l.isApproved)
            .fold<int>(0, (sum, l) => sum + l.totalDays);
        final isMobile = MediaQuery.of(context).size.width <= 768;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            isMobile ? 16 : 24,
            isMobile ? 90 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              if (isMobile)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/mobile-home');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave Register',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'My Leaves & Time Off',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => ApplyLeaveDialog.show(context),
                      icon: const Icon(LucideIcons.calendarPlus, size: 14),
                      label: const Text('Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Leaves & Time Off',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apply for leaves and track approval status from HR.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => ApplyLeaveDialog.show(context),
                      icon: const Icon(LucideIcons.calendarPlus, size: 16),
                      label: const Text('Apply for Leave'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Employee Stats
              if (isMobile)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _StatCard(
                        title: 'Pending HR Approval',
                        value: '$pending',
                        subtitle: 'Awaiting review',
                        color: Colors.amber,
                        icon: LucideIcons.clock,
                        isExpanded: false,
                        width: 190,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        title: 'Approved Leaves',
                        value: '$approvedDays days',
                        subtitle: 'Taken this year',
                        color: AppColors.success,
                        icon: LucideIcons.calendarCheck,
                        isExpanded: false,
                        width: 190,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        title: 'Total Requests',
                        value: '${leaves.length}',
                        subtitle: 'Submitted applications',
                        color: AppColors.primary,
                        icon: LucideIcons.fileText,
                        isExpanded: false,
                        width: 190,
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    _StatCard(
                      title: 'Pending HR Approval',
                      value: '$pending',
                      subtitle: 'Awaiting review',
                      color: Colors.amber,
                      icon: LucideIcons.clock,
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      title: 'Approved Leaves',
                      value: '$approvedDays days',
                      subtitle: 'Taken this year',
                      color: AppColors.success,
                      icon: LucideIcons.calendarCheck,
                    ),
                    const SizedBox(width: 14),
                    _StatCard(
                      title: 'Total Requests',
                      value: '${leaves.length}',
                      subtitle: 'Submitted applications',
                      color: AppColors.primary,
                      icon: LucideIcons.fileText,
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Leave History & Applications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),

              if (leaves.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(LucideIcons.calendar, size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'You haven\'t applied for any leaves yet',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ApplyLeaveDialog.show(context),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Apply Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leaves.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final leave = leaves[index];
                    return _LeaveCard(
                      leave: leave,
                      isHR: false,
                      onCancel: leave.isPending
                          ? () => ref.read(leaveControllerProvider.notifier).cancelLeave(leave.id)
                          : null,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Common Leave List Builder
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLeaveList(List<LeaveRequest> list, Agent hrUser, {required bool isHR}) {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.inbox, size: 44, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No requests match your search' : 'No leave requests in this category',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        12,
        isMobile ? 16 : 24,
        isMobile ? 90 : 16,
      ),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final leave = list[index];
        return _LeaveCard(
          leave: leave,
          isHR: isHR,
          onApprove: isHR && leave.isPending
              ? () => ref.read(leaveControllerProvider.notifier).approveLeave(
                    leave: leave,
                    hrAgent: hrUser,
                  )
              : null,
          onReject: isHR && leave.isPending ? () => _showRejectDialog(leave, hrUser) : null,
          onCancel: !isHR && leave.isPending
              ? () => ref.read(leaveControllerProvider.notifier).cancelLeave(leave.id)
              : null,
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool highlight;
  final bool isExpanded;
  final double? width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.highlight = false,
    this.isExpanded = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: highlight ? 0.5 : 0.2)),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isExpanded) {
      return Expanded(child: cardContent);
    }
    return cardContent;
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final bool isHR;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _LeaveCard({
    required this.leave,
    required this.isHR,
    this.onApprove,
    this.onReject,
    this.onCancel,
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
    final isMobile = MediaQuery.of(context).size.width <= 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: leave.isPending ? Colors.amber.withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      child: isMobile ? _buildMobile(context, fmt) : _buildDesktop(context, fmt),
    );
  }

  Widget _buildMobile(BuildContext context, DateFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Avatar + Name & Role + Status Badge
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                leave.agentName.isNotEmpty ? leave.agentName[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leave.agentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    leave.agentRole,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                leave.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Badges: Date Range + Type
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendar, size: 12, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    leave.dateRangeFormatted,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '(${leave.totalDays} ${leave.totalDays == 1 ? "day" : "days"})',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                leave.leaveType,
                style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),

        if (leave.reason != null && leave.reason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Reason: ${leave.reason}',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],

        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              'Requested on ${fmt.format(leave.createdAt)}',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
            if (leave.isApproved && leave.approvedByName != null)
              Text(
                '• Approved by ${leave.approvedByName}',
                style: const TextStyle(fontSize: 10, color: AppColors.success),
              ),
            if (leave.isRejected && leave.rejectionReason != null)
              Text(
                '• Rejected: "${leave.rejectionReason}"',
                style: const TextStyle(fontSize: 10, color: AppColors.error),
              ),
          ],
        ),

        if (leave.isPending) ...[
          const SizedBox(height: 12),
          if (isHR && onApprove != null && onReject != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(LucideIcons.check, size: 14),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(LucideIcons.x, size: 14),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          if (!isHR && onCancel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.white54),
                label: const Text('Cancel Request', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildDesktop(BuildContext context, DateFormat fmt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            leave.agentName.isNotEmpty ? leave.agentName[0].toUpperCase() : 'A',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    leave.agentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      leave.agentRole,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendar, size: 12, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          leave.dateRangeFormatted,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${leave.totalDays} ${leave.totalDays == 1 ? "day" : "days"})',
                          style: const TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      leave.leaveType,
                      style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
                    ),
                  ),
                ],
              ),
              if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reason: ${leave.reason}',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    'Requested on ${fmt.format(leave.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  if (leave.isApproved && leave.approvedByName != null)
                    Text(
                      '• Approved by ${leave.approvedByName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.success),
                    ),
                  if (leave.isRejected && leave.rejectionReason != null)
                    Text(
                      '• Rejection reason: "${leave.rejectionReason}"',
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
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
            if (leave.isPending) ...[
              const SizedBox(height: 10),
              if (isHR && onApprove != null && onReject != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(LucideIcons.check, size: 14),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(LucideIcons.x, size: 14),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              if (!isHR && onCancel != null)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(LucideIcons.trash2, size: 14, color: Colors.white54),
                  label: const Text('Cancel Request', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
