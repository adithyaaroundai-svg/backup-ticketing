import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/layout/main_layout.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../providers/lead_provider.dart';
import '../../domain/entities/lead.dart';
import '../widgets/edit_lead_dialog.dart';

class LeadsPage extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const LeadsPage({super.key, this.isEmbedded = false});

  @override
  ConsumerState<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends ConsumerState<LeadsPage> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsStreamProvider);

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
        final isMobile = constraints.maxWidth < 800;
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
                      children: [
                        Text(
                          'Pipeline',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.w900,
                            color: context.adaptiveSlate900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 56), // Provide space for floating top buttons

                // Pipeline Stats
                leadsAsync.when(
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

            // Kanban Board
            Expanded(
              child: leadsAsync.when(
                data: (leads) {
                  var columns = ['New Lead', 'Contacted', 'Qualified', 'Negotiation'];
                  
                  final wonLeads = leads.where((d) => d.status == 'Won' || d.status == 'win').toList();
                  final lostLeads = leads.where((d) => d.status == 'Lost' || d.status == 'loss').toList();

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
                                        width: 160, // Reduced fixed width for mobile Kanban columns
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
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(width: 16),
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
      currentPath: '/leads',
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

  const _VerticalStatusTab({
    required this.status,
    required this.count,
    required this.color,
    required this.leads,
    required this.onStageChange,
    required this.onDelete,
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

  const _KanbanColumn({
    required this.status,
    required this.leads,
    required this.onStageChange,
    required this.onDelete,
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
                            )
                          : _LeadCard(
                              lead: leads[index],
                              color: statusColor,
                              onStageChange: (newStage) => onStageChange(leads[index], newStage),
                              onDelete: () => onDelete(leads[index]),
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

  const _CustomerCard({
    required this.lead,
    required this.color,
    required this.onStageChange,
    required this.onDelete,
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

  const _LeadCard({
    required this.lead,
    required this.color,
    required this.onStageChange,
    required this.onDelete,
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
                            Icon(LucideIcons.calendar, size: 14, color: context.adaptiveSlate400),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormat('yyyy-MM-dd').format(lead.createdAt),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.error),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (lead.followUpDate != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Follow-up: ${DateFormat('MMM d, yyyy').format(lead.followUpDate!)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
