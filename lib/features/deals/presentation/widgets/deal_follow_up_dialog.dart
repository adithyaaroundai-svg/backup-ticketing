import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../providers/deals_provider.dart';
import '../../services/deal_follow_up_service.dart';

class DealFollowUpDialog extends ConsumerStatefulWidget {
  final List<Deal> initialDeals;

  const DealFollowUpDialog({
    super.key,
    required this.initialDeals,
  });

  @override
  ConsumerState<DealFollowUpDialog> createState() => _DealFollowUpDialogState();
}

class _DealFollowUpDialogState extends ConsumerState<DealFollowUpDialog> {
  late List<Deal> _deals;

  @override
  void initState() {
    super.initState();
    _deals = List.from(widget.initialDeals);
  }

  Future<void> _handleDismiss(Deal deal) async {
    await DealFollowUpService.dismissFollowUp(deal.id, deal.followUpDate);
    if (!mounted) return;

    setState(() {
      _deals.removeWhere((d) => d.id == deal.id);
    });

    ref.invalidate(dealsProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow-up for "${deal.name}" dismissed. It will not be reminded again.'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.slate800,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (_deals.isEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _handleSnooze(Deal deal) async {
    final now = DateTime.now();

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.alarmClock, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Snooze Follow-Up for "${deal.name}"',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select when you want to be reminded about this deal:',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(LucideIcons.clock, color: Color(0xFFD97706)),
                title: const Text('In 1 Hour'),
                subtitle: Text(DateFormat('h:mm a').format(now.add(const Duration(hours: 1)))),
                onTap: () => Navigator.of(bottomSheetCtx).pop(now.add(const Duration(hours: 1))),
              ),
              ListTile(
                leading: const Icon(LucideIcons.clock4, color: Color(0xFFD97706)),
                title: const Text('In 3 Hours'),
                subtitle: Text(DateFormat('h:mm a').format(now.add(const Duration(hours: 3)))),
                onTap: () => Navigator.of(bottomSheetCtx).pop(now.add(const Duration(hours: 3))),
              ),
              ListTile(
                leading: const Icon(LucideIcons.sun, color: Color(0xFFD97706)),
                title: const Text('Tomorrow Morning'),
                subtitle: Text('Tomorrow at 9:00 AM (${DateFormat('dd MMM').format(now.add(const Duration(days: 1)))})'),
                onTap: () {
                  final tomorrow = now.add(const Duration(days: 1));
                  Navigator.of(bottomSheetCtx).pop(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0));
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.calendarDays, color: Color(0xFFD97706)),
                title: const Text('Pick Date & Time...'),
                subtitle: const Text('Choose a custom follow-up date and time'),
                onTap: () async {
                  Navigator.of(bottomSheetCtx).pop();

                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: DateTime(now.year + 2),
                  );

                  if (pickedDate == null || !mounted) return;

                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );

                  final finalTime = pickedTime ?? const TimeOfDay(hour: 9, minute: 0);
                  final combined = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    finalTime.hour,
                    finalTime.minute,
                  );

                  await _applySnooze(deal, combined);
                },
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      await _applySnooze(deal, result);
    }
  }

  Future<void> _applySnooze(Deal deal, DateTime snoozeUntil) async {
    await DealFollowUpService.snoozeFollowUp(
      ref: ref,
      deal: deal,
      snoozeUntil: snoozeUntil,
    );

    if (!mounted) return;

    setState(() {
      _deals.removeWhere((d) => d.id == deal.id);
    });

    ref.invalidate(dealsProvider);

    final formattedSnooze = DateFormat('dd MMM, h:mm a').format(snoozeUntil);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow-up for "${deal.name}" snoozed until $formattedSnooze'),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (_deals.isEmpty && mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = GlassColors.of(context, ref);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: gc.isGlass ? Colors.white.withValues(alpha: 0.95) : gc.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 620,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.bellRing, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Follow-Up Reminders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_deals.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_deals.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Deals requiring your attention for follow-up today',
                        style: TextStyle(fontSize: 13, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: AppColors.slate400, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Deals List
            if (_deals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.checkCheck, color: Color(0xFF10B981), size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All Follow-Ups Handled! 🎉',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No pending follow-ups remaining for today.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _deals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final deal = _deals[index];
                    return _buildDealFollowUpCard(deal);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealFollowUpCard(Deal deal) {
    final hasCompany = deal.companyName != null && deal.companyName!.trim().isNotEmpty;
    final hasPhone = deal.phoneNumber.trim().isNotEmpty;
    final hasRemark = deal.remark.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, Company & Follow Up Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                    if (hasCompany) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(LucideIcons.building, size: 13, color: AppColors.slate500),
                          const SizedBox(width: 4),
                          Text(
                            deal.companyName!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (deal.followUpDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.calendarClock, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        deal.followUpDate!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Contact phone if present
          if (hasPhone) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.phone, size: 13, color: AppColors.slate500),
                const SizedBox(width: 6),
                Text(
                  deal.phoneNumber.trim(),
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: deal.phoneNumber.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number copied!'), duration: Duration(seconds: 1)),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.copy, size: 13, color: AppColors.slate400),
                  ),
                ),
              ],
            ),
          ],

          // What to follow up (Remark)
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.messageSquareQuote, size: 14, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What to follow up:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasRemark ? deal.remark.trim() : 'No specific remark entered.',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasRemark ? const Color(0xFF78350F) : AppColors.slate500,
                          fontStyle: hasRemark ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Snooze & Dismiss
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Snooze Button
              OutlinedButton.icon(
                onPressed: () => _handleSnooze(deal),
                icon: const Icon(LucideIcons.alarmClock, size: 15, color: Color(0xFFD97706)),
                label: const Text('Snooze'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFFDE68A)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 10),
              // Dismiss Button
              ElevatedButton.icon(
                onPressed: () => _handleDismiss(deal),
                icon: const Icon(LucideIcons.checkCheck, size: 15),
                label: const Text('Dismiss'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
