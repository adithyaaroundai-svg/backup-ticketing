import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/layout/main_layout.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../providers/lead_provider.dart';
import '../../domain/entities/lead.dart';
import '../widgets/edit_lead_dialog.dart';
import '../widgets/create_lead_dialog.dart';

class PrivateLeadsPage extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const PrivateLeadsPage({super.key, this.isEmbedded = false});

  @override
  ConsumerState<PrivateLeadsPage> createState() => _PrivateLeadsPageState();
}

class _PrivateLeadsPageState extends ConsumerState<PrivateLeadsPage> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  String? _selectedFilter;
  bool _isFollowUpSidebarOpen = true;
  String _followUpFilter = 'All'; // 'All', 'Overdue', 'Today', 'Upcoming', 'No Date'
  String _followUpSearch = '';

  void _showMobileFollowUpSheet(BuildContext context, List<Lead> leads) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.isDarkMode ? context.adaptiveCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _FollowUpSidebar(
            leads: leads,
            filter: _followUpFilter,
            searchQuery: _followUpSearch,
            onFilterChanged: (newFilter) {
              setState(() => _followUpFilter = newFilter);
            },
            onSearchChanged: (query) {
              setState(() => _followUpSearch = query);
            },
            onClose: () => Navigator.pop(ctx),
            onStageChange: (lead, newStatus) {
              ref.read(leadControllerProvider.notifier).updateLeadStatus(lead.id, newStatus);
            },
            onDelete: (lead) {
              ref.read(leadControllerProvider.notifier).deleteLead(lead.id);
            },
            onAddRemark: (lead, remark) {
              final dateStr = DateFormat('MMM d h:mm a').format(DateTime.now());
              final newDesc = (lead.description == null || lead.description!.isEmpty)
                  ? '[$dateStr]: $remark'
                  : '${lead.description}\n[$dateStr]: $remark';
              ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'description': newDesc});
            },
            onUpdateFollowUpDate: (lead, newDate) {
              final formattedDate = newDate != null ? DateFormat('yyyy-MM-dd').format(newDate) : null;
              ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'follow_up_date': formattedDate});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(privateLeadsProvider);

    // Listen to controller errors
    ref.listen(leadControllerProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        return Column(
          children: [
            // Header Section
            if (!widget.isEmbedded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? context.adaptiveCard : Colors.white,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Private Pipeline',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: context.adaptiveSlate900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Follow-up toggle button
                        ElevatedButton.icon(
                          onPressed: () {
                            if (isMobile) {
                              leadsAsync.whenData((leads) {
                                _showMobileFollowUpSheet(context, leads);
                              });
                            } else {
                              setState(() {
                                _isFollowUpSidebarOpen = !_isFollowUpSidebarOpen;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowUpSidebarOpen && !isMobile
                                ? (context.isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0))
                                : AppColors.primaryLight,
                            foregroundColor: _isFollowUpSidebarOpen && !isMobile
                                ? context.adaptiveSlate900
                                : Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 10 : 14,
                              vertical: 8,
                            ),
                          ),
                          icon: Icon(
                            _isFollowUpSidebarOpen && !isMobile
                                ? LucideIcons.panelRightClose
                                : LucideIcons.calendarClock,
                            size: 16,
                          ),
                          label: Text(
                            isMobile
                                ? 'Follow-ups'
                                : (_isFollowUpSidebarOpen ? 'Hide Follow-ups' : 'Follow-up Dates'),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const CreateLeadDialog(isPrivatePipeline: true),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 10 : 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Add Lead', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 56), // Provide space for floating top buttons

            // Pipeline Stats
            leadsAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              data: (leads) {
                final totalCount = leads.length;
                final wonCount = leads.where((d) => d.status.toLowerCase() == 'win' || d.status.toLowerCase() == 'won').length;
                final lostCount = leads.where((d) => d.status.toLowerCase() == 'loss' || d.status.toLowerCase() == 'lost').length;
                final pendingCount = leads.where((d) => d.status.toLowerCase() == 'pending' || d.status.toLowerCase() == 'new').length;

                final statsRow = Row(
                  children: [
                    _EnhancedStatCard(
                      label: 'Total Pipeline',
                      value: totalCount.toString(),
                      color: _selectedFilter == null ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                      icon: LucideIcons.trendingUp,
                      isExpanded: !isMobile,
                      width: isMobile ? 220 : null,
                      onTap: () {
                        setState(() { _selectedFilter = null; });
                      },
                    ),
                    const SizedBox(width: 16),
                    _EnhancedStatCard(
                      label: 'Our Customers',
                      value: wonCount.toString(),
                      color: _selectedFilter == 'Won' ? AppColors.success : AppColors.success.withValues(alpha: 0.5),
                      icon: LucideIcons.users,
                      isExpanded: !isMobile,
                      width: isMobile ? 220 : null,
                      onTap: () {
                        setState(() { _selectedFilter = 'Won'; });
                      },
                    ),
                    const SizedBox(width: 16),
                    _EnhancedStatCard(
                      label: 'Not Our Customers',
                      value: lostCount.toString(),
                      color: _selectedFilter == 'Lost' ? AppColors.error : AppColors.error.withValues(alpha: 0.5),
                      icon: LucideIcons.userX,
                      isExpanded: !isMobile,
                      width: isMobile ? 220 : null,
                      onTap: () {
                        setState(() { _selectedFilter = 'Lost'; });
                      },
                    ),
                    const SizedBox(width: 16),
                    _EnhancedStatCard(
                      label: 'Active (Pending)',
                      value: pendingCount.toString(),
                      color: _selectedFilter == 'Pending' ? AppColors.info : AppColors.info.withValues(alpha: 0.5),
                      icon: LucideIcons.target,
                      isExpanded: !isMobile,
                      width: isMobile ? 220 : null,
                      onTap: () {
                        setState(() { _selectedFilter = 'Pending'; });
                      },
                    ),
                  ],
                );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: isMobile
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: statsRow,
                        )
                      : statsRow,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // Kanban Board & Follow-up Sidebar
            Expanded(
              child: leadsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (leads) {
                  var columns = ['New Lead', 'Contacted', 'Qualified', 'Negotiation'];

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Main Kanban Area
                        Expanded(
                          child: isMobile
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: columns.map((status) {
                                      final statusLeads = leads.where((d) {
                                        if (status == 'New Lead' && (d.status == 'pending' || d.status == 'New')) return true;
                                        return d.status == status;
                                      }).toList();

                                      return SizedBox(
                                        width: 160,
                                        child: _KanbanColumn(
                                          status: status,
                                          leads: statusLeads,
                                          onStageChange: (lead, newStatus) {
                                            ref
                                                .read(leadControllerProvider.notifier)
                                                .updateLeadStatus(lead.id, newStatus);
                                          },
                                          onDelete: (lead) {
                                            ref
                                                .read(leadControllerProvider.notifier)
                                                .deleteLead(lead.id);
                                          },
                                          onAddRemark: (lead, remark) {
                                            final dateStr = DateFormat('MMM d h:mm a').format(DateTime.now());
                                            final newDesc = (lead.description == null || lead.description!.isEmpty)
                                                ? '[$dateStr]: $remark'
                                                : '${lead.description}\n[$dateStr]: $remark';
                                            ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'description': newDesc});
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: columns.map((status) {
                                    final statusLeads = leads.where((d) {
                                      if (status == 'New Lead' && (d.status == 'pending' || d.status == 'New')) return true;
                                      return d.status == status;
                                    }).toList();

                                    return Expanded(
                                      child: _KanbanColumn(
                                        status: status,
                                        leads: statusLeads,
                                        onStageChange: (lead, newStatus) {
                                          ref
                                              .read(leadControllerProvider.notifier)
                                              .updateLeadStatus(lead.id, newStatus);
                                        },
                                        onDelete: (lead) {
                                          ref
                                              .read(leadControllerProvider.notifier)
                                              .deleteLead(lead.id);
                                        },
                                        onAddRemark: (lead, remark) {
                                          final dateStr = DateFormat('MMM d h:mm a').format(DateTime.now());
                                          final newDesc = (lead.description == null || lead.description!.isEmpty)
                                              ? '[$dateStr]: $remark'
                                              : '${lead.description}\n[$dateStr]: $remark';
                                          ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'description': newDesc});
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),

                        // Follow-up Date Right Sidebar on Desktop/Tablet
                        if (_isFollowUpSidebarOpen && !isMobile) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 260,
                            child: _FollowUpSidebar(
                              leads: leads,
                              filter: _followUpFilter,
                              searchQuery: _followUpSearch,
                              onFilterChanged: (newFilter) {
                                setState(() => _followUpFilter = newFilter);
                              },
                              onSearchChanged: (query) {
                                setState(() => _followUpSearch = query);
                              },
                              onClose: () {
                                setState(() => _isFollowUpSidebarOpen = false);
                              },
                              onStageChange: (lead, newStatus) {
                                ref.read(leadControllerProvider.notifier).updateLeadStatus(lead.id, newStatus);
                              },
                              onDelete: (lead) {
                                ref.read(leadControllerProvider.notifier).deleteLead(lead.id);
                              },
                              onAddRemark: (lead, remark) {
                                final dateStr = DateFormat('MMM d h:mm a').format(DateTime.now());
                                final newDesc = (lead.description == null || lead.description!.isEmpty)
                                    ? '[$dateStr]: $remark'
                                    : '${lead.description}\n[$dateStr]: $remark';
                                ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'description': newDesc});
                              },
                              onUpdateFollowUpDate: (lead, newDate) {
                                final formattedDate = newDate != null ? DateFormat('yyyy-MM-dd').format(newDate) : null;
                                ref.read(leadControllerProvider.notifier).updateLeadDetails(lead.id, {'follow_up_date': formattedDate});
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        );
      },
    );

    if (widget.isEmbedded) {
      return content;
    }

    return MainLayout(
      currentPath: '/private-leads',
      child: Scaffold(
        backgroundColor: context.isDarkMode ? context.adaptiveBackground : AppColors.slate50,
        body: content,
      ),
    );
  }
}

class _EnhancedStatCard extends StatefulWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isExpanded;
  final double? width;
  final VoidCallback? onTap;

  const _EnhancedStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isExpanded = true,
    this.width,
    this.onTap,
  });

  @override
  State<_EnhancedStatCard> createState() => _EnhancedStatCardState();
}

class _EnhancedStatCardState extends State<_EnhancedStatCard> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.95 : (_isHovered ? 1.02 : 1.0);
    final shadowBlur = _isHovered ? 16.0 : 10.0;
    final shadowOffset = _isHovered ? const Offset(0, 6) : const Offset(0, 4);

    Widget card = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: widget.width,
        decoration: BoxDecoration(
          color: context.isDarkMode ? context.adaptiveCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.color.withValues(alpha: 0.3) : context.adaptiveBorder,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
              blurRadius: shadowBlur,
              offset: shadowOffset,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onHover: (hovered) => setState(() => _isHovered = hovered),
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isExpanded ? 16 : 12,
                vertical: widget.isExpanded ? 12 : 6,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: EdgeInsets.all(widget.isExpanded ? 8 : 6),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: _isHovered ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: widget.isExpanded ? 20 : 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.isExpanded ? 11 : 10,
                          color: context.adaptiveSlate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: widget.isExpanded ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          color: context.adaptiveSlate900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
      
    return widget.isExpanded ? Expanded(child: card) : card;
  }
}

class _VerticalStatusTab extends StatelessWidget {
  final String status;
  final int count;
  final Color color;
  final List<Lead> leads;
  final void Function(Lead, String) onStageChange;
  final void Function(Lead) onDelete;
  final void Function(Lead, String) onAddRemark;

  const _VerticalStatusTab({
    required this.status,
    required this.count,
    required this.color,
    required this.leads,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
  });

  void _showKanbanPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: context.isDarkMode ? const Color(0xFF1E293B) : AppColors.slate50,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _KanbanColumn(
                status: status,
                leads: leads,
                onStageChange: onStageChange,
                onDelete: onDelete,
                onAddRemark: onAddRemark,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showKanbanPopup(context),
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withValues(alpha: 0.05),
        child: Container(
          width: 32,
          alignment: Alignment.center,
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              '$status ($count)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String status;
  final List<Lead> leads;
  final void Function(Lead, String) onStageChange;
  final void Function(Lead) onDelete;
  final void Function(Lead, String) onAddRemark;

  const _KanbanColumn({
    required this.status,
    required this.leads,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
  });

  Color get statusColor {
    switch (status) {
      case 'New Lead': return AppColors.slate500;
      case 'Contacted': return AppColors.info;
      case 'Qualified': return AppColors.primaryLight;
      case 'Proposal': return Colors.purple.shade400;
      case 'Negotiation': return Colors.deepOrange;
      case 'Won': return AppColors.success;
      case 'Lost': return AppColors.error;
      default: return AppColors.slate500;
    }
  }

  String get _statusLabel {
    return status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: status == 'Lost' ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _statusLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${leads.length} - ₹0',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Lead Cards List
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDarkMode ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
              ),
              child: leads.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text('-', style: TextStyle(color: context.adaptiveSlate400, fontSize: 16)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: leads.length,
                      itemBuilder: (context, index) => status == 'Won'
                          ? _CustomerCard(
                              lead: leads[index],
                              color: statusColor,
                              onStageChange: (newStage) => onStageChange(leads[index], newStage),
                              onDelete: () => onDelete(leads[index]),
                              onAddRemark: (remark) => onAddRemark(leads[index], remark),
                            )
                          : _LeadCard(
                              lead: leads[index],
                              color: statusColor,
                              onStageChange: (newStage) => onStageChange(leads[index], newStage),
                              onDelete: () => onDelete(leads[index]),
                              onAddRemark: (remark) => onAddRemark(leads[index], remark),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Lead lead;
  final Color color;
  final void Function(String) onStageChange;
  final VoidCallback onDelete;
  final void Function(String) onAddRemark;

  const _CustomerCard({
    required this.lead,
    required this.color,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode 
            ? Color.alphaBlend(color.withValues(alpha: 0.16), const Color(0xFF1E293B))
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.isDarkMode ? color.withValues(alpha: 0.4) : context.adaptiveBorder, 
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 3,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CUSTOMER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lead.companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.adaptiveSlate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(LucideIcons.pencil, size: 14, color: context.adaptiveSlate500),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => EditLeadDialog(lead: lead),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          splashRadius: 14,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(LucideIcons.trash2, size: 14, color: context.adaptiveSlate400),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          splashRadius: 14,
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: context.adaptiveBorder),
                ),
                _DetailRow(icon: LucideIcons.indianRupee, label: 'Deal Value', value: '₹${lead.amount.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                _DetailRow(icon: LucideIcons.phone, label: 'Phone', value: lead.phoneNumber ?? 'N/A'),
                const SizedBox(height: 4),
                _DetailRow(icon: LucideIcons.calendar, label: 'Customer Since', value: DateFormat('MMM d, yyyy').format(lead.createdAt)),
                if (lead.followUpDate != null) ...[
                  const SizedBox(height: 4),
                  _DetailRow(
                    icon: LucideIcons.clock,
                    label: 'Follow-up',
                    value: DateFormat('MMM d, yyyy').format(lead.followUpDate!),
                  ),
                ],
                if (lead.description != null && lead.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lead.description!,
                    style: TextStyle(fontSize: 11, color: context.adaptiveSlate600, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Stage Dropdown
                PopupMenuButton<String>(
                  onSelected: (String nextStage) {
                    onStageChange(nextStage);
                  },
                  itemBuilder: (BuildContext context) {
                    return ['New Lead', 'Contacted', 'Qualified', 'Negotiation', 'Won', 'Lost'].map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice, style: TextStyle(fontSize: 13, color: context.adaptiveSlate700)),
                      );
                    }).toList();
                  },
                  offset: const Offset(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.adaptiveBorder),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          (lead.status == 'pending' || lead.status == 'New') ? 'New Lead' : (lead.status == 'win' ? 'Won' : (lead.status == 'loss' ? 'Lost' : lead.status)), 
                          style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                        ),
                        Icon(LucideIcons.chevronDown, size: 16, color: context.adaptiveSlate400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: context.adaptiveSlate400),
        const SizedBox(width: 4),
        Text(
          '$label:',
          style: TextStyle(fontSize: 11, color: context.adaptiveSlate500, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 11, color: context.adaptiveSlate700, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final Color color;
  final void Function(String) onStageChange;
  final VoidCallback onDelete;
  final void Function(String) onAddRemark;

  const _LeadCard({
    required this.lead,
    required this.color,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode 
            ? Color.alphaBlend(color.withValues(alpha: 0.16), const Color(0xFF1E293B))
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.isDarkMode
              ? color.withValues(alpha: 0.5)
              : (lead.status == 'pending' || lead.status == 'New' || lead.status == 'New Lead' ? Colors.orange.shade300 : context.adaptiveBorder),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.02),
            blurRadius: context.isDarkMode ? 6 : 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _showLeadDetailsPopup(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.companyName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primaryLight),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (lead.product != null && lead.product!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lead.product!,
                    style: TextStyle(fontSize: 12, color: context.adaptiveSlate500),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLeadDetailsPopup(BuildContext context) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: context.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lead.companyName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryLight),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.isDarkMode ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'LEAD',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => EditLeadDialog(lead: lead),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(LucideIcons.pencil, size: 16, color: context.adaptiveSlate500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (lead.product != null && lead.product!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(LucideIcons.box, size: 14, color: context.adaptiveSlate500),
                        const SizedBox(width: 6),
                        Text(
                          lead.product!,
                          style: TextStyle(fontSize: 14, color: context.adaptiveSlate700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(height: 1, color: context.adaptiveBorder),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.phone, size: 14, color: context.adaptiveSlate400),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                lead.phoneNumber ?? 'N/A',
                                style: TextStyle(fontSize: 14, color: context.adaptiveSlate600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.calendarClock, size: 14, color: context.adaptiveSlate400),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(
                                  lead.followUpDate != null ? DateFormat('dd-MM-yyyy').format(lead.followUpDate!) : 'No follow-up',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: lead.followUpDate != null ? AppColors.error : context.adaptiveSlate500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (lead.description != null && lead.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      lead.description!,
                      style: TextStyle(fontSize: 13, color: context.adaptiveSlate600, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.black.withValues(alpha: 0.25) : AppColors.slate50,
                      border: Border.all(color: context.isDarkMode ? Colors.white.withValues(alpha: 0.12) : context.adaptiveBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (String nextStage) {
                        onStageChange(nextStage);
                        Navigator.pop(context);
                      },
                      itemBuilder: (BuildContext context) {
                        return ['New Lead', 'Contacted', 'Qualified', 'Negotiation', 'Won', 'Lost'].map((String choice) {
                          return PopupMenuItem<String>(
                            value: choice,
                            child: Text(choice, style: TextStyle(fontSize: 14, color: context.adaptiveSlate700)),
                          );
                        }).toList();
                      },
                      offset: const Offset(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              (lead.status == 'pending' || lead.status == 'New') ? 'New Lead' : (lead.status == 'win' ? 'Won' : (lead.status == 'loss' ? 'Lost' : lead.status)), 
                              style: TextStyle(fontSize: 14, color: context.adaptiveSlate700, fontWeight: FontWeight.w600),
                            ),
                            Icon(LucideIcons.chevronDown, size: 18, color: context.adaptiveSlate500),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarkController,
                    maxLines: 2,
                    style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                    decoration: InputDecoration(
                      hintText: 'Add a remark after follow-up...',
                      hintStyle: TextStyle(fontSize: 13, color: context.adaptiveSlate400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: context.isDarkMode ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.adaptiveBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.adaptiveBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primaryLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (remarkController.text.trim().isNotEmpty) {
                          onAddRemark(remarkController.text.trim());
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(LucideIcons.save, size: 16),
                      label: const Text('Save Remark'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onDelete();
                        Navigator.pop(context);
                      },
                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                      label: const Text('Delete Lead', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum FollowUpCategory { overdue, today, tomorrow, upcoming, noDate }

class _FollowUpSidebar extends StatelessWidget {
  final List<Lead> leads;
  final String filter;
  final String searchQuery;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClose;
  final void Function(Lead, String) onStageChange;
  final void Function(Lead) onDelete;
  final void Function(Lead, String) onAddRemark;
  final void Function(Lead, DateTime?) onUpdateFollowUpDate;

  const _FollowUpSidebar({
    required this.leads,
    required this.filter,
    required this.searchQuery,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onClose,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
    required this.onUpdateFollowUpDate,
  });

  FollowUpCategory _categorize(DateTime? date) {
    if (date == null) return FollowUpCategory.noDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return FollowUpCategory.overdue;
    if (diff == 0) return FollowUpCategory.today;
    if (diff == 1) return FollowUpCategory.tomorrow;
    return FollowUpCategory.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final overdueLeads = leads.where((l) => _categorize(l.followUpDate) == FollowUpCategory.overdue).toList();
    final todayLeads = leads.where((l) => _categorize(l.followUpDate) == FollowUpCategory.today).toList();
    final upcomingLeads = leads.where((l) {
      final cat = _categorize(l.followUpDate);
      return cat == FollowUpCategory.tomorrow || cat == FollowUpCategory.upcoming;
    }).toList();
    final noDateLeads = leads.where((l) => _categorize(l.followUpDate) == FollowUpCategory.noDate).toList();

    // Sort today leads (soonest first / by followUpDate)
    todayLeads.sort((a, b) => (a.followUpDate ?? a.createdAt).compareTo(b.followUpDate ?? b.createdAt));
    // Sort overdue leads (most recent overdue first)
    overdueLeads.sort((a, b) => (b.followUpDate ?? b.createdAt).compareTo(a.followUpDate ?? a.createdAt));
    // Sort upcoming leads (soonest upcoming first)
    upcomingLeads.sort((a, b) => (a.followUpDate ?? a.createdAt).compareTo(b.followUpDate ?? b.createdAt));

    List<Lead> filterByQuery(List<Lead> list) {
      if (searchQuery.trim().isEmpty) return list;
      final q = searchQuery.toLowerCase().trim();
      return list.where((l) {
        return l.companyName.toLowerCase().contains(q) ||
            (l.customerName?.toLowerCase().contains(q) ?? false) ||
            (l.phoneNumber?.toLowerCase().contains(q) ?? false) ||
            (l.product?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    final filteredTodayLeads = filterByQuery(todayLeads);
    final filteredOverdueLeads = filterByQuery(overdueLeads);
    final filteredUpcomingLeads = filterByQuery(upcomingLeads);
    final filteredNoDateLeads = filterByQuery(noDateLeads);

    final totalDisplayedCount = (filter == 'All' || filter == 'Today' ? filteredTodayLeads.length : 0) +
        (filter == 'All' || filter == 'Overdue' ? filteredOverdueLeads.length : 0) +
        (filter == 'All' || filter == 'Upcoming' ? filteredUpcomingLeads.length : 0) +
        (filter == 'All' || filter == 'No Date' ? filteredNoDateLeads.length : 0);

    return Container(
      decoration: BoxDecoration(
        color: context.isDarkMode ? context.adaptiveCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.adaptiveBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: context.isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: context.adaptiveBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(LucideIcons.calendarClock, size: 14, color: AppColors.primaryLight),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Follow-ups',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.adaptiveSlate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${leads.where((l) => l.followUpDate != null).length} of ${leads.length} set',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.adaptiveSlate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (todayLeads.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${todayLeads.length} Today',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                    ),
                  )
                else if (overdueLeads.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${overdueLeads.length} Missed',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 14, color: context.adaptiveSlate400),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  splashRadius: 12,
                  tooltip: 'Close sidebar',
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: SizedBox(
              height: 34,
              child: TextField(
                onChanged: onSearchChanged,
                style: TextStyle(fontSize: 12, color: context.adaptiveSlate900),
                decoration: InputDecoration(
                  hintText: 'Search follow-ups...',
                  hintStyle: TextStyle(fontSize: 12, color: context.adaptiveSlate400),
                  prefixIcon: Icon(LucideIcons.search, size: 14, color: context.adaptiveSlate400),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  filled: true,
                  fillColor: context.isDarkMode ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // Filter Segment Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All (${leads.length})',
                    isSelected: filter == 'All',
                    onTap: () => onFilterChanged('All'),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    label: 'Today (${todayLeads.length})',
                    isSelected: filter == 'Today',
                    onTap: () => onFilterChanged('Today'),
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    label: 'Missed (${overdueLeads.length})',
                    isSelected: filter == 'Overdue',
                    onTap: () => onFilterChanged('Overdue'),
                    color: AppColors.error,
                    isUrgent: overdueLeads.isNotEmpty,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    label: 'Upcoming (${upcomingLeads.length})',
                    isSelected: filter == 'Upcoming',
                    onTap: () => onFilterChanged('Upcoming'),
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 4),
                  _FilterChip(
                    label: 'No Date (${noDateLeads.length})',
                    isSelected: filter == 'No Date',
                    onTap: () => onFilterChanged('No Date'),
                    color: context.adaptiveSlate500,
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: context.adaptiveBorder),

          // Cards List with Priority Section Grouping (Due Today first!)
          Expanded(
            child: totalDisplayedCount == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendarCheck, size: 36, color: context.adaptiveSlate400),
                          const SizedBox(height: 8),
                          Text(
                            filter == 'All'
                                ? 'No leads found'
                                : 'No leads in $filter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.adaptiveSlate600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Assign follow-up dates to track your calls & demos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.adaptiveSlate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    children: [
                      // 1. Due Today Section (Prioritized First)
                      if (filter == 'All' || filter == 'Today') ...[
                        if (filteredTodayLeads.isNotEmpty) ...[
                          _FollowUpSectionHeader(
                            title: 'Due Today',
                            count: filteredTodayLeads.length,
                            color: Colors.amber.shade700,
                          ),
                          ...filteredTodayLeads.map((lead) => _FollowUpLeadCard(
                                lead: lead,
                                onStageChange: (newStage) => onStageChange(lead, newStage),
                                onDelete: () => onDelete(lead),
                                onAddRemark: (remark) => onAddRemark(lead, remark),
                                onUpdateFollowUpDate: (newDate) => onUpdateFollowUpDate(lead, newDate),
                              )),
                        ],
                      ],

                      // 2. Missed / Overdue Section
                      if (filter == 'All' || filter == 'Overdue') ...[
                        if (filteredOverdueLeads.isNotEmpty) ...[
                          _FollowUpSectionHeader(
                            title: 'Missed',
                            count: filteredOverdueLeads.length,
                            color: AppColors.error,
                          ),
                          ...filteredOverdueLeads.map((lead) => _FollowUpLeadCard(
                                lead: lead,
                                onStageChange: (newStage) => onStageChange(lead, newStage),
                                onDelete: () => onDelete(lead),
                                onAddRemark: (remark) => onAddRemark(lead, remark),
                                onUpdateFollowUpDate: (newDate) => onUpdateFollowUpDate(lead, newDate),
                              )),
                        ],
                      ],

                      // 3. Upcoming Section
                      if (filter == 'All' || filter == 'Upcoming') ...[
                        if (filteredUpcomingLeads.isNotEmpty) ...[
                          _FollowUpSectionHeader(
                            title: 'Upcoming',
                            count: filteredUpcomingLeads.length,
                            color: AppColors.info,
                          ),
                          ...filteredUpcomingLeads.map((lead) => _FollowUpLeadCard(
                                lead: lead,
                                onStageChange: (newStage) => onStageChange(lead, newStage),
                                onDelete: () => onDelete(lead),
                                onAddRemark: (remark) => onAddRemark(lead, remark),
                                onUpdateFollowUpDate: (newDate) => onUpdateFollowUpDate(lead, newDate),
                              )),
                        ],
                      ],

                      // 4. No Date Section
                      if (filter == 'All' || filter == 'No Date') ...[
                        if (filteredNoDateLeads.isNotEmpty) ...[
                          _FollowUpSectionHeader(
                            title: 'No Follow-up Date',
                            count: filteredNoDateLeads.length,
                            color: context.adaptiveSlate500,
                          ),
                          ...filteredNoDateLeads.map((lead) => _FollowUpLeadCard(
                                lead: lead,
                                onStageChange: (newStage) => onStageChange(lead, newStage),
                                onDelete: () => onDelete(lead),
                                onAddRemark: (remark) => onAddRemark(lead, remark),
                                onUpdateFollowUpDate: (newDate) => onUpdateFollowUpDate(lead, newDate),
                              )),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _FollowUpSectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      child: Row(
        children: [
          Container(
            width: 7.5,
            height: 7.5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.adaptiveSlate800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;
  final bool isUrgent;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : (context.isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUrgent && !isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : context.adaptiveSlate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpLeadCard extends StatelessWidget {
  final Lead lead;
  final void Function(String) onStageChange;
  final VoidCallback onDelete;
  final void Function(String) onAddRemark;
  final void Function(DateTime?) onUpdateFollowUpDate;

  const _FollowUpLeadCard({
    required this.lead,
    required this.onStageChange,
    required this.onDelete,
    required this.onAddRemark,
    required this.onUpdateFollowUpDate,
  });

  FollowUpCategory get category {
    if (lead.followUpDate == null) return FollowUpCategory.noDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(lead.followUpDate!.year, lead.followUpDate!.month, lead.followUpDate!.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return FollowUpCategory.overdue;
    if (diff == 0) return FollowUpCategory.today;
    if (diff == 1) return FollowUpCategory.tomorrow;
    return FollowUpCategory.upcoming;
  }

  Color get categoryColor {
    switch (category) {
      case FollowUpCategory.overdue:
        return AppColors.error;
      case FollowUpCategory.today:
        return Colors.orange.shade700;
      case FollowUpCategory.tomorrow:
        return AppColors.info;
      case FollowUpCategory.upcoming:
        return AppColors.primaryLight;
      case FollowUpCategory.noDate:
        return AppColors.slate400;
    }
  }

  String get categoryText {
    if (lead.followUpDate == null) return 'Set Follow-up Date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(lead.followUpDate!.year, lead.followUpDate!.month, lead.followUpDate!.day);
    final diff = target.difference(today).inDays;
    final timeStr = DateFormat('h:mm a').format(lead.followUpDate!);
    final isDefaultMidnight = lead.followUpDate!.hour == 0 && lead.followUpDate!.minute == 0;
    final timeSuffix = isDefaultMidnight ? '' : ' at $timeStr';
    
    if (diff < 0) {
      final days = diff.abs();
      return '${DateFormat('MMM d').format(lead.followUpDate!)}$timeSuffix ($days ${days == 1 ? 'day' : 'days'} overdue)';
    }
    if (diff == 0) return 'Due Today$timeSuffix';
    if (diff == 1) return 'Tomorrow$timeSuffix';
    return '${DateFormat('MMM d').format(lead.followUpDate!)}$timeSuffix';
  }

  Future<void> _pickDate(BuildContext context) async {
    final initial = lead.followUpDate ?? DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: context.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              onSurface: context.adaptiveSlate900,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onUpdateFollowUpDate(picked);
    }
  }

  void _showRemarkDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(LucideIcons.messageSquarePlus, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add Remark - ${lead.companyName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter follow-up outcome or remarks...',
              hintStyle: TextStyle(fontSize: 13, color: context.adaptiveSlate400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: context.adaptiveBorder),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.adaptiveSlate500)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAddRemark(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Color.alphaBlend(color.withValues(alpha: 0.1), const Color(0xFF1E293B))
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: category == FollowUpCategory.overdue
              ? AppColors.error.withValues(alpha: 0.5)
              : (category == FollowUpCategory.today ? Colors.orange.shade400 : context.adaptiveBorder),
          width: category == FollowUpCategory.overdue || category == FollowUpCategory.today ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Company Name & Stage Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 6, 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    lead.companyName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: context.adaptiveSlate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Stage Pill with Quick Menu
                PopupMenuButton<String>(
                  onSelected: (nextStage) => onStageChange(nextStage),
                  itemBuilder: (ctx) => ['New Lead', 'Contacted', 'Qualified', 'Negotiation', 'Won', 'Lost'].map((choice) {
                    return PopupMenuItem<String>(
                      value: choice,
                      child: Text(choice, style: TextStyle(fontSize: 12, color: context.adaptiveSlate700)),
                    );
                  }).toList(),
                  offset: const Offset(0, 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: context.adaptiveBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (lead.status == 'pending' || lead.status == 'New')
                              ? 'New'
                              : (lead.status == 'win' ? 'Won' : (lead.status == 'loss' ? 'Lost' : lead.status)),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: context.adaptiveSlate700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(LucideIcons.chevronDown, size: 10, color: context.adaptiveSlate400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contact Details & Product
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                if (lead.phoneNumber != null && lead.phoneNumber!.isNotEmpty) ...[
                  Icon(LucideIcons.phone, size: 10, color: context.adaptiveSlate400),
                  const SizedBox(width: 3),
                  Text(
                    lead.phoneNumber!,
                    style: TextStyle(fontSize: 10.5, color: context.adaptiveSlate600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                ],
                if (lead.product != null && lead.product!.isNotEmpty) ...[
                  Icon(LucideIcons.box, size: 10, color: context.adaptiveSlate400),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      lead.product!,
                      style: TextStyle(fontSize: 10.5, color: context.adaptiveSlate500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 5),

          // Follow-up Date Pill (Clickable to change date)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickDate(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category == FollowUpCategory.overdue ? LucideIcons.alertTriangle : LucideIcons.calendar,
                        size: 11.5,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          categoryText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(LucideIcons.pencil, size: 10, color: color),
                      if (lead.followUpDate != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => onUpdateFollowUpDate(null),
                          child: Icon(LucideIcons.x, size: 11, color: color),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Latest Remarks snippet if available
          if (lead.description != null && lead.description!.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.messageSquare, size: 9, color: context.adaptiveSlate400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lead.description!,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: context.adaptiveSlate600,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Footer actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _showRemarkDialog(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.plus, size: 11, color: AppColors.primaryLight),
                        const SizedBox(width: 2),
                        const Text(
                          'Add Remark',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.externalLink, size: 13, color: context.adaptiveSlate500),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditLeadDialog(lead: lead),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      splashRadius: 10,
                      tooltip: 'Edit details',
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: Icon(LucideIcons.trash2, size: 12, color: context.adaptiveSlate400),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      splashRadius: 10,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

