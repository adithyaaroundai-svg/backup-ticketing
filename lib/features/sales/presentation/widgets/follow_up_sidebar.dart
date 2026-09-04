import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../domain/entities/lead.dart';
import '../widgets/edit_lead_dialog.dart';

class FollowUpSidebar extends StatelessWidget {
  final List<Lead> leads;
  
  const FollowUpSidebar({super.key, required this.leads});

  @override
  Widget build(BuildContext context) {
    // Filter active leads (exclude 'won' and 'loss' or 'lost')
    final activeLeads = leads.where((l) {
      final status = l.status.toLowerCase();
      return status != 'won' && status != 'win' && status != 'loss' && status != 'lost';
    }).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final missed = <Lead>[];
    final dueToday = <Lead>[];
    final upcoming = <Lead>[];

    for (final lead in activeLeads) {
      if (lead.followUpDate != null) {
        // Convert to local timezone before comparing dates
        final fDateLocal = lead.followUpDate!.toLocal();
        final fDate = DateTime(fDateLocal.year, fDateLocal.month, fDateLocal.day);
        
        if (fDate.isBefore(today)) {
          missed.add(lead);
        } else if (fDate.isAtSameMomentAs(today)) {
          dueToday.add(lead);
        } else {
          upcoming.add(lead);
        }
      }
    }

    // Sort by follow-up date ascending
    missed.sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
    dueToday.sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));
    upcoming.sort((a, b) => a.followUpDate!.compareTo(b.followUpDate!));

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: context.isDarkMode ? context.adaptiveCard : Colors.white,
        border: Border(left: BorderSide(color: context.adaptiveBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(LucideIcons.calendarClock, size: 20, color: context.adaptiveSlate800),
                const SizedBox(width: 8),
                Text(
                  'Follow-Ups',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.adaptiveSlate900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (missed.isNotEmpty) ...[
                  _SectionHeader(title: 'Missed', color: Colors.red.shade600, count: missed.length),
                  ...missed.map((l) => _FollowUpCard(lead: l)),
                  const SizedBox(height: 16),
                ],
                
                if (dueToday.isNotEmpty) ...[
                  _SectionHeader(title: 'Due Today', color: Colors.orange.shade600, count: dueToday.length),
                  ...dueToday.map((l) => _FollowUpCard(lead: l)),
                  const SizedBox(height: 16),
                ],
                
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(title: 'Upcoming', color: AppColors.primary, count: upcoming.length),
                  ...upcoming.map((l) => _FollowUpCard(lead: l)),
                  const SizedBox(height: 16),
                ],
                
                if (missed.isEmpty && dueToday.isEmpty && upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.checkCircle, size: 48, color: AppColors.success.withAlpha(150)),
                          const SizedBox(height: 12),
                          Text(
                            'All caught up!',
                            style: TextStyle(
                              color: context.adaptiveSlate600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'No pending follow-ups.',
                            style: TextStyle(
                              color: context.adaptiveSlate400,
                              fontSize: 13,
                            ),
                          ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int count;

  const _SectionHeader({required this.title, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: context.adaptiveSlate700, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final Lead lead;
  
  const _FollowUpCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    final followUp = lead.followUpDate!.toLocal();
    
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => EditLeadDialog(lead: lead),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.isDarkMode ? context.adaptiveBackground : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.adaptiveBorder),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead.companyName,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.adaptiveSlate800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(LucideIcons.calendar, size: 12, color: context.adaptiveSlate500),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(followUp)} at ${timeFormat.format(followUp)}',
                  style: TextStyle(fontSize: 11, color: context.adaptiveSlate500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
