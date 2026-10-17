import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../services/deal_summary_service.dart';

class DealRegisterRecipientsTab extends ConsumerStatefulWidget {
  const DealRegisterRecipientsTab({super.key});

  @override
  ConsumerState<DealRegisterRecipientsTab> createState() => _DealRegisterRecipientsTabState();
}

class _DealRegisterRecipientsTabState extends ConsumerState<DealRegisterRecipientsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  Set<String> _selectedRecipientIds = {};
  Set<String> _enrolledMemberIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentAgent = ref.read(authProvider);
    if (currentAgent == null) return;

    setState(() => _isLoading = true);

    final selected = await DealSummaryService.getSelectedRecipientIds(currentAgent.id);
    final enrolled = await DealSummaryService.getDealRegisterMemberIds();

    if (mounted) {
      setState(() {
        _selectedRecipientIds = selected;
        _enrolledMemberIds = enrolled;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRecipient(Map<String, dynamic> agent, bool? isChecked) async {
    final currentAgent = ref.read(authProvider);
    if (currentAgent == null) return;

    final agentId = agent['id']?.toString() ?? '';
    if (agentId.isEmpty) return;

    final updated = Set<String>.from(_selectedRecipientIds);

    if (isChecked == true) {
      updated.add(agentId);

      // Auto-enroll in deal-register channel if not already enrolled
      if (!_enrolledMemberIds.contains(agentId)) {
        await DealSummaryService.addMemberToDealRegister(agentId);
        setState(() {
          _enrolledMemberIds.add(agentId);
        });
        if (mounted) {
          final agentName = agent['full_name'] ?? agent['username'] ?? 'User';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$agentName is now enrolled in #deal-register'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } else {
      updated.remove(agentId);
    }

    setState(() {
      _selectedRecipientIds = updated;
    });

    await DealSummaryService.saveSelectedRecipientIds(currentAgent.id, updated);
  }

  Future<void> _handleSendNow() async {
    final currentAgent = ref.read(authProvider);
    if (currentAgent == null) return;

    final deals = await DealSummaryService.getSenderTodayDeals(currentAgent.id);

    if (!mounted) return;

    // Show preview dialog before sending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Preview Today\'s Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.slate400),
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF10B981),
                            child: Text(
                              currentAgent.fullName.isNotEmpty ? currentAgent.fullName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            currentAgent.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              currentAgent.role,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.slate200),
                      const SizedBox(height: 12),
                      Text(
                        DealSummaryService.formatSummaryMarkdown(
                          senderName: currentAgent.fullName,
                          senderRole: currentAgent.role,
                          deals: deals,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Will be sent privately to ${_selectedRecipientIds.length} checked recipient(s) in #deal-register.',
                  style: const TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.slate600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(LucideIcons.send, size: 16),
                      label: const Text('Send Summary Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    final error = await DealSummaryService.sendDailySummary(
      ref: ref,
      isManual: true,
      recipientIdsOverride: _selectedRecipientIds,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send summary: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily summary successfully sent to your selected recipients in #deal-register!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = GlassColors.of(context, ref);
    final agentsAsync = ref.watch(agentsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Automation Banner & Trigger Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: gc.isGlass ? Colors.white.withValues(alpha: 0.08) : gc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gc.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.clock, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Daily 5:00 PM Automation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: gc.onSurface,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every day at 5:00 PM IST, a summary of your deals will be sent to the ticked recipients in #deal-register. Each recipient only sees the messages intended for them.',
                      style: TextStyle(fontSize: 13, color: gc.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _handleSendNow,
                icon: _isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(_isSending ? 'Sending...' : 'Send Summary Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Section Title & Search Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deal Register Recipients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: gc.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tick who will receive your 5:00 PM summary. Ticking a new user automatically adds them to the deal register channel.',
                  style: TextStyle(fontSize: 13, color: gc.onSurfaceMuted),
                ),
              ],
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 13, color: gc.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(color: gc.onSurfaceFaint, fontSize: 13),
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: gc.onSurfaceFaint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: gc.isGlass ? Colors.white.withValues(alpha: 0.05) : gc.surfaceHeader,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: gc.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: gc.border),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Members List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          agentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Center(child: Text('Error loading members: $err')),
            data: (allAgents) {
              final filtered = allAgents.where((a) {
                final name = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                final role = (a['role'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || role.contains(_searchQuery);
              }).toList()
                ..sort((a, b) {
                  final idA = a['id']?.toString() ?? '';
                  final idB = b['id']?.toString() ?? '';
                  final isCheckedA = _selectedRecipientIds.contains(idA) ? 0 : 1;
                  final isCheckedB = _selectedRecipientIds.contains(idB) ? 0 : 1;
                  if (isCheckedA != isCheckedB) return isCheckedA.compareTo(isCheckedB);
                  final nameA = (a['full_name'] ?? a['username'] ?? '').toString().toLowerCase();
                  final nameB = (b['full_name'] ?? b['username'] ?? '').toString().toLowerCase();
                  return nameA.compareTo(nameB);
                });

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      'No members found matching "$_searchQuery"',
                      style: TextStyle(color: gc.onSurfaceMuted),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: gc.isGlass ? Colors.white.withValues(alpha: 0.06) : gc.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gc.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: gc.border),
                  itemBuilder: (context, index) {
                    final agent = filtered[index];
                    final agentId = agent['id']?.toString() ?? '';
                    final isChecked = _selectedRecipientIds.contains(agentId);
                    final isEnrolled = _enrolledMemberIds.contains(agentId);
                    final fullName = agent['full_name'] ?? agent['username'] ?? 'User';
                    final role = agent['role'] ?? 'Member';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleRecipient(agent, !isChecked),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => _toggleRecipient(agent, val),
                              ),
                              const SizedBox(width: 12),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isChecked
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : gc.surfaceHeader,
                                child: Text(
                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isChecked ? const Color(0xFF10B981) : gc.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                                        color: gc.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      role,
                                      style: TextStyle(fontSize: 12, color: gc.onSurfaceMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (isEnrolled) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Deal Register Member',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ] else if (isChecked) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'Will Auto-Enroll',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
