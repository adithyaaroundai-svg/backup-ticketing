import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/glass_card.dart';
import '../providers/deals_provider.dart';
import 'create_deal_dialog.dart';

class DealsTable extends ConsumerStatefulWidget {
  const DealsTable({super.key});

  @override
  ConsumerState<DealsTable> createState() => _DealsTableState();
}

class _DealsTableState extends ConsumerState<DealsTable> {
  bool? _forceCardView;

  String? _addingDateKey;
  String? _selectedDate;
  String? _selectedFollowUpDate;

  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _remarkController = TextEditingController();
  final _phoneController = TextEditingController();
  final _scrollController = ScrollController();

  String? _editingDealId;
  String? _editingField;
  final _editNameController = TextEditingController();
  final _editCompanyController = TextEditingController();
  final _editRemarkController = TextEditingController();
  final _editPhoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _remarkController.dispose();
    _phoneController.dispose();
    _editNameController.dispose();
    _editCompanyController.dispose();
    _editRemarkController.dispose();
    _editPhoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAddingDeal(String dateKey) {
    setState(() {
      _addingDateKey = dateKey;
      _selectedDate = dateKey;
      _selectedFollowUpDate = null;
      _nameController.clear();
      _companyController.clear();
      _remarkController.clear();
      _phoneController.clear();
    });
  }

  void _cancelAdding() => setState(() {
    _addingDateKey = null;
    _selectedDate = null;
    _selectedFollowUpDate = null;
    _nameController.clear();
    _companyController.clear();
    _remarkController.clear();
    _phoneController.clear();
  });

  Future<void> _submitDeal(String dateKey) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _cancelAdding();
      return;
    }

    final targetDate = (_selectedDate != null && _selectedDate!.trim().isNotEmpty)
        ? _selectedDate!.trim()
        : (dateKey.trim().isNotEmpty
            ? dateKey.trim()
            : DateTime.now().toIso8601String().substring(0, 10));

    final error = await ref.read(dealControllerProvider.notifier).addDeal(
          name: name,
          companyName: _companyController.text.trim(),
          date: targetDate,
          remark: _remarkController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          followUpDate: (_selectedFollowUpDate != null &&
                  _selectedFollowUpDate!.trim().isNotEmpty)
              ? _selectedFollowUpDate!.trim()
              : null,
        );

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add deal: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      _cancelAdding();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deal added successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _startEditingDeal(Deal deal, String field) {
    setState(() {
      _editingDealId = deal.id;
      _editingField = field;
      _editNameController.text = deal.name;
      _editCompanyController.text = deal.companyName ?? '';
      _editRemarkController.text = deal.remark;
      _editPhoneController.text = deal.phoneNumber;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingDealId = null;
      _editingField = null;
    });
  }

  Future<void> _submitEdit(Deal deal) async {
    final name = _editNameController.text.trim();
    final targetDate = deal.date.isNotEmpty
        ? deal.date
        : DateTime.now().toIso8601String().substring(0, 10);

    final error = await ref.read(dealControllerProvider.notifier).updateDeal(
          id: deal.id,
          name: name.isEmpty ? deal.name : name,
          companyName: _editCompanyController.text.trim(),
          date: targetDate,
          remark: _editRemarkController.text.trim(),
          phoneNumber: _editPhoneController.text.trim(),
          followUpDate: deal.followUpDate,
        );

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update deal: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      _cancelEditing();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context, Deal deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deal'),
        content: Text('Are you sure you want to delete "${deal.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(dealControllerProvider.notifier).deleteDeal(deal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = GlassColors.of(context, ref);
    final dealsAsync = ref.watch(dealsProvider);
    final isScreenMobile = MediaQuery.of(context).size.width < 750;
    final useCardView = _forceCardView ?? isScreenMobile;

    return dealsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (deals) {
        final groupedDeals = groupBy(deals, (Deal d) => d.createdAt);
        final sortedDates = groupedDeals.keys.toList()..sort((a, b) => b.compareTo(a));

        if (sortedDates.isEmpty) {
          final today = DateTime.now();
          final todayStr =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          sortedDates.add(todayStr);
          groupedDeals[todayStr] = [];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top View Switcher Toolbar
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.briefcase, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          '${deals.length} Deal${deals.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // View mode toggle
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: gc.isGlass ? Colors.white.withValues(alpha: 0.08) : gc.surfaceHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: gc.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() => _forceCardView = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: useCardView
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.layoutGrid,
                                  size: 14,
                                  color: useCardView ? const Color(0xFF10B981) : gc.onSurfaceMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cards',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: useCardView ? FontWeight.bold : FontWeight.w500,
                                    color: useCardView ? const Color(0xFF10B981) : gc.onSurfaceMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() => _forceCardView = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: !useCardView
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.table,
                                  size: 14,
                                  color: !useCardView ? const Color(0xFF10B981) : gc.onSurfaceMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Table',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: !useCardView ? FontWeight.bold : FontWeight.w500,
                                    color: !useCardView ? const Color(0xFF10B981) : gc.onSurfaceMuted,
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
            ),

            // Card View for Mobile or Table View
            if (useCardView)
              _buildMobileCardsView(sortedDates, groupedDeals, gc)
            else
              _buildTableView(sortedDates, groupedDeals, gc, isScreenMobile),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE CARDS VIEW (Fully responsive, all options visible on phone screen)
  // ---------------------------------------------------------------------------
  Widget _buildMobileCardsView(
    List<String> sortedDates,
    Map<String, List<Deal>> groupedDeals,
    GlassColors gc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final date in sortedDates) ...[
          // Date Group Header
          Container(
            margin: const EdgeInsets.only(top: 14, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: gc.surfaceHeader,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gc.border),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendarDays, size: 16, color: gc.onSurface),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: gc.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gc.isGlass ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${groupedDeals[date]?.length ?? 0}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: gc.onSurfaceFaint,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _startAddingDeal(date),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 13, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'Add Deal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inline Add Deal Card for this date
          if (_addingDateKey == date)
            _buildMobileAddDealCard(date, gc),

          // Deal Cards for this date
          if (groupedDeals[date]!.isEmpty && _addingDateKey != date)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gc.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gc.border.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text(
                  'No deals recorded for this date. Tap "Add Deal" above.',
                  style: TextStyle(fontSize: 12.5, color: gc.onSurfaceMuted),
                ),
              ),
            ),

          for (final deal in groupedDeals[date]!)
            _buildDealCard(deal, gc),
        ],
      ],
    );
  }

  Widget _buildDealCard(Deal deal, GlassColors gc) {
    final hasCompany = deal.companyName != null && deal.companyName!.trim().isNotEmpty;
    final hasPhone = deal.phoneNumber.trim().isNotEmpty;
    final hasRemark = deal.remark.trim().isNotEmpty;
    final hasFollowUp = deal.followUpDate != null && deal.followUpDate!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: gc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header: Deal Name & Follow Up badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deal.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: gc.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(LucideIcons.building2, size: 13, color: gc.onSurfaceMuted),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              hasCompany ? deal.companyName! : 'No company specified',
                              style: TextStyle(
                                fontSize: 13,
                                color: hasCompany ? gc.onSurface : gc.onSurfaceMuted,
                                fontWeight: hasCompany ? FontWeight.w500 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Follow Up Pill
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: hasFollowUp
                          ? (DateTime.tryParse(deal.followUpDate!) ?? DateTime.now())
                          : DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      final nd =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      ref.read(dealControllerProvider.notifier).updateDeal(
                            id: deal.id,
                            name: deal.name,
                            companyName: deal.companyName,
                            date: deal.date,
                            remark: deal.remark,
                            phoneNumber: deal.phoneNumber,
                            followUpDate: nd,
                          );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasFollowUp
                          ? const Color(0xFFD97706).withValues(alpha: 0.14)
                          : gc.surfaceHeader,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasFollowUp
                            ? const Color(0xFFD97706).withValues(alpha: 0.4)
                            : gc.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.calendarClock,
                          size: 12,
                          color: hasFollowUp ? const Color(0xFFD97706) : gc.onSurfaceMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasFollowUp
                              ? (deal.followUpDate!.length >= 10
                                  ? deal.followUpDate!.substring(0, 10)
                                  : deal.followUpDate!)
                              : '+ Follow-Up',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: hasFollowUp ? const Color(0xFFD97706) : gc.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Phone Number Row (with direct call button)
          if (hasPhone)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: gc.isGlass ? Colors.white.withValues(alpha: 0.05) : gc.surfaceHeader,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.phone, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deal.phoneNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: gc.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _makePhoneCall(deal.phoneNumber),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.phoneCall, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Call',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Remark Box
          if (hasRemark)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gc.isGlass ? Colors.white.withValues(alpha: 0.04) : gc.surfaceHeader,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gc.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.fileText, size: 13, color: gc.onSurfaceMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        deal.remark,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: gc.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Divider(height: 16, color: gc.border),

          // Action Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 12, color: gc.onSurfaceFaint),
                const SizedBox(width: 4),
                Text(
                  'Created ${deal.createdAt}',
                  style: TextStyle(fontSize: 11, color: gc.onSurfaceFaint),
                ),
                const Spacer(),
                // Edit Dialog button
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CreateDealDialog(dealToEdit: deal),
                    );
                  },
                  icon: const Icon(LucideIcons.pencil, size: 13),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(context, deal),
                  icon: const Icon(LucideIcons.trash2, size: 14, color: AppColors.error),
                  tooltip: 'Delete Deal',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAddDealCard(String date, GlassColors gc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.plusCircle, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Add New Deal ($date)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: gc.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _cancelAdding,
                icon: Icon(LucideIcons.x, size: 16, color: gc.onSurfaceMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(fontSize: 13.5, color: gc.onSurface),
            decoration: InputDecoration(
              labelText: 'Deal Name *',
              hintText: 'e.g. Tally Prime Gold Renewal',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _companyController,
            style: TextStyle(fontSize: 13.5, color: gc.onSurface),
            decoration: InputDecoration(
              labelText: 'Company Name',
              hintText: 'e.g. Sunrise Industries',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 13.5, color: gc.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91 9876543210',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Follow-up date picker button
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedFollowUpDate != null
                        ? (DateTime.tryParse(_selectedFollowUpDate!) ?? DateTime.now())
                        : DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedFollowUpDate =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _selectedFollowUpDate != null
                        ? const Color(0xFFD97706).withValues(alpha: 0.12)
                        : gc.surfaceHeader,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedFollowUpDate != null
                          ? const Color(0xFFD97706)
                          : gc.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.calendarClock,
                        size: 14,
                        color: _selectedFollowUpDate != null
                            ? const Color(0xFFD97706)
                            : gc.onSurfaceMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedFollowUpDate != null
                            ? _selectedFollowUpDate!.substring(5)
                            : 'Follow-Up',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedFollowUpDate != null
                              ? const Color(0xFFD97706)
                              : gc.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remarkController,
            maxLines: 2,
            style: TextStyle(fontSize: 13.5, color: gc.onSurface),
            decoration: InputDecoration(
              labelText: 'Remark / Notes',
              hintText: 'Customer requested quotation by Tuesday...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelAdding,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _submitDeal(date),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Save Deal'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TABLE VIEW (Horizontal Scrollable with swipe indicator on mobile)
  // ---------------------------------------------------------------------------
  Widget _buildTableView(
    List<String> sortedDates,
    Map<String, List<Deal>> groupedDeals,
    GlassColors gc,
    bool isScreenMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isScreenMobile)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.arrowLeftRight, size: 13, color: Color(0xFF2563EB)),
                SizedBox(width: 6),
                Text(
                  'Swipe table horizontally to view all columns',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: gc.isGlass
                ? ImageFilter.blur(sigmaX: 16, sigmaY: 16)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                color: gc.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gc.border),
                gradient: gc.isGlass
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      )
                    : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth > 950 ? constraints.maxWidth : 950,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: gc.isGlass
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : gc.surface,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: _headerText('Deals', gc)),
                                  Expanded(flex: 3, child: _headerText('Company Name', gc)),
                                  Expanded(flex: 2, child: _headerText('Date', gc)),
                                  Expanded(flex: 2, child: _headerText('Follow Up', gc)),
                                  Expanded(flex: 3, child: _headerText('Remark', gc)),
                                  Expanded(flex: 2, child: _headerText('Phone Number', gc)),
                                ],
                              ),
                            ),

                            for (final date in sortedDates) ...[
                              // Group Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: gc.surfaceHeader,
                                  border: Border(
                                    top: BorderSide(color: gc.border),
                                    bottom: BorderSide(color: gc.border),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.calendarDays, size: 16, color: gc.onSurface),
                                    const SizedBox(width: 8),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: gc.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${groupedDeals[date]?.length ?? 0} item${groupedDeals[date]?.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: gc.onSurfaceFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Deal rows
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: groupedDeals[date]!.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: gc.border),
                                itemBuilder: (context, index) {
                                  final deal = groupedDeals[date]![index];
                                  final isEditingName =
                                      _editingDealId == deal.id && _editingField == 'name';
                                  final isEditingCompany =
                                      _editingDealId == deal.id && _editingField == 'company';
                                  final isEditingRemark =
                                      _editingDealId == deal.id && _editingField == 'remark';
                                  final isEditingPhone =
                                      _editingDealId == deal.id && _editingField == 'phone';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    color: gc.isGlass ? Colors.transparent : gc.surface,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: isEditingName
                                                ? _editRow(
                                                    controller: _editNameController,
                                                    gc: gc,
                                                    onSubmit: () => _submitEdit(deal),
                                                    onCancel: _cancelEditing,
                                                  )
                                                : _cellTap(
                                                    onTap: () => _startEditingDeal(deal, 'name'),
                                                    text: deal.name,
                                                    bold: true,
                                                    gc: gc,
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: isEditingCompany
                                                ? _editRow(
                                                    controller: _editCompanyController,
                                                    gc: gc,
                                                    onSubmit: () => _submitEdit(deal),
                                                    onCancel: _cancelEditing,
                                                  )
                                                : _cellTap(
                                                    onTap: () => _startEditingDeal(deal, 'company'),
                                                    text: (deal.companyName != null &&
                                                            deal.companyName!.isNotEmpty)
                                                        ? deal.companyName!
                                                        : '-',
                                                    bold: false,
                                                    gc: gc,
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: Text(
                                              deal.createdAt,
                                              style: TextStyle(fontSize: 14, color: gc.onSurface),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: deal.followUpDate != null
                                                      ? (DateTime.tryParse(deal.followUpDate!) ??
                                                          DateTime.now())
                                                      : DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                                if (picked != null) {
                                                  final nd =
                                                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                                  if (nd != deal.followUpDate) {
                                                    ref
                                                        .read(dealControllerProvider.notifier)
                                                        .updateDeal(
                                                          id: deal.id,
                                                          name: deal.name,
                                                          companyName: deal.companyName,
                                                          date: deal.date,
                                                          remark: deal.remark,
                                                          phoneNumber: deal.phoneNumber,
                                                          followUpDate: nd,
                                                        );
                                                  }
                                                }
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      deal.followUpDate != null
                                                          ? (deal.followUpDate!.length >= 10
                                                              ? deal.followUpDate!.substring(0, 10)
                                                              : deal.followUpDate!)
                                                          : 'Follow Up',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: deal.followUpDate != null
                                                            ? gc.onSurface
                                                            : gc.onSurfaceMuted,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(LucideIcons.pencil,
                                                      size: 12, color: gc.onSurfaceFaint),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16),
                                            child: isEditingRemark
                                                ? _editRow(
                                                    controller: _editRemarkController,
                                                    gc: gc,
                                                    onSubmit: () => _submitEdit(deal),
                                                    onCancel: _cancelEditing,
                                                  )
                                                : _cellTap(
                                                    onTap: () => _startEditingDeal(deal, 'remark'),
                                                    text: deal.remark,
                                                    bold: false,
                                                    gc: gc,
                                                  ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: isEditingPhone
                                              ? _editRow(
                                                  controller: _editPhoneController,
                                                  gc: gc,
                                                  onSubmit: () => _submitEdit(deal),
                                                  onCancel: _cancelEditing,
                                                )
                                              : _cellTap(
                                                  onTap: () => _startEditingDeal(deal, 'phone'),
                                                  text: deal.phoneNumber,
                                                  bold: false,
                                                  gc: gc,
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Add item row
                              if (_addingDateKey == date)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: gc.isGlass ? Colors.transparent : gc.surface,
                                    border: Border(top: BorderSide(color: gc.border)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: TextField(
                                            controller: _nameController,
                                            autofocus: true,
                                            style: TextStyle(fontSize: 14, color: gc.onSurface),
                                            decoration: InputDecoration(
                                              hintText: 'Deal name',
                                              hintStyle: TextStyle(color: gc.onSurfaceFaint),
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            onSubmitted: (_) => _submitDeal(date),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: TextField(
                                            controller: _companyController,
                                            style: TextStyle(fontSize: 14, color: gc.onSurface),
                                            decoration: InputDecoration(
                                              hintText: 'Company name',
                                              hintStyle: TextStyle(color: gc.onSurfaceFaint),
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                            onSubmitted: (_) => _submitDeal(date),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  DateTime.tryParse(_selectedDate ?? date) ??
                                                      DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _selectedDate =
                                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                              });
                                            }
                                          },
                                          child: Row(
                                            children: [
                                              Text(
                                                _selectedDate ?? date,
                                                style: TextStyle(fontSize: 14, color: gc.onSurface),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(LucideIcons.calendarDays,
                                                  size: 14, color: gc.onSurfaceFaint),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: _selectedFollowUpDate != null
                                                  ? (DateTime.tryParse(_selectedFollowUpDate!) ??
                                                      DateTime.now())
                                                  : DateTime.now(),
                                              firstDate: DateTime(2000),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                _selectedFollowUpDate =
                                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                              });
                                            }
                                          },
                                          child: Row(
                                            children: [
                                              Text(
                                                _selectedFollowUpDate ?? 'Follow Up',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _selectedFollowUpDate != null
                                                      ? gc.onSurface
                                                      : gc.onSurfaceMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(LucideIcons.calendarDays,
                                                  size: 14, color: gc.onSurfaceFaint),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: _remarkController,
                                          style: TextStyle(fontSize: 14, color: gc.onSurface),
                                          decoration: InputDecoration(
                                            hintText: 'Remark',
                                            hintStyle: TextStyle(color: gc.onSurfaceFaint),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) => _submitDeal(date),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _phoneController,
                                                style: TextStyle(fontSize: 14, color: gc.onSurface),
                                                decoration: InputDecoration(
                                                  hintText: 'Phone',
                                                  hintStyle: TextStyle(color: gc.onSurfaceFaint),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                ),
                                                onSubmitted: (_) => _submitDeal(date),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(LucideIcons.check,
                                                  color: AppColors.success, size: 18),
                                              onPressed: () => _submitDeal(date),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(LucideIcons.x,
                                                  color: gc.onSurfaceFaint, size: 18),
                                              onPressed: _cancelAdding,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                InkWell(
                                  onTap: () => _startAddingDeal(date),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: gc.isGlass ? Colors.transparent : gc.surface,
                                      border: Border(
                                        top: BorderSide(color: gc.border),
                                        bottom: BorderSide(color: gc.border),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.plus, size: 16, color: gc.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Add item',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: gc.primary,
                                          ),
                                        ),
                                      ],
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerText(String label, GlassColors gc) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: gc.onSurface,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _cellTap({
    required VoidCallback onTap,
    required String text,
    required bool bold,
    required GlassColors gc,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
                color: gc.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          Icon(LucideIcons.pencil, size: 12, color: gc.onSurfaceFaint),
        ],
      ),
    );
  }

  Widget _editRow({
    required TextEditingController controller,
    required GlassColors gc,
    required VoidCallback onSubmit,
    required VoidCallback onCancel,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: gc.onSurface),
            decoration: InputDecoration(
              border: UnderlineInputBorder(borderSide: BorderSide(color: gc.primary)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onSubmit,
          child: const Icon(LucideIcons.check, color: AppColors.success, size: 16),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onCancel,
          child: Icon(LucideIcons.x, color: gc.onSurfaceFaint, size: 16),
        ),
      ],
    );
  }
}
