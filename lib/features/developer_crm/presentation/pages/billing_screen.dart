import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/theme/app_colors.dart';
import '../../../../core/design_system/theme/app_theme.dart';
import '../../core/money_utils.dart';
import '../../core/time_utils.dart';
import '../../domain/entities/billing.dart';
import '../providers/auth_provider.dart';
import '../providers/billing_provider.dart';
import '../widgets/board_chrome.dart';
import '../widgets/common.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final prov = context.read<BillingProvider>();
        if (prov.data == null && !prov.loading) {
          prov.load();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _BillingBody();
  }
}

class _BillingBody extends StatelessWidget {
  const _BillingBody();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BillingProvider>();
    final authProv = context.watch<AuthProvider>();

    if (prov.loading && prov.data == null) {
      return const CenterLoading();
    }
    if (prov.error != null && prov.data == null) {
      return ErrorBanner(message: prov.error!, onRetry: prov.load);
    }

    final data = prov.data;
    if (data == null) return const CenterLoading();

    return RefreshIndicator(
      onRefresh: prov.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: BoardPageHeader(
                    title: 'Billing',
                    subtitle: 'Client billing ledger, advances, and outstanding balances.',
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: prov.loading ? null : prov.load,
                ),
              ],
            ),

            if (data.readOnly) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Read-only view for accountants.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.adaptiveSlate800),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Filter Tabs (All / Billed / Pending Billing)
            _FilterTabs(
              currentFilter: prov.filter,
              totalCount: prov.totalCount,
              billedCount: prov.billedCount,
              unbilledCount: prov.unbilledCount,
              onFilterChanged: prov.setFilter,
            ),

            const SizedBox(height: 16),

            // Grand Summary Cards (Responsive Row)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final cards = [
                  _SummaryStatCard(
                    label: 'Grand Billed',
                    value: data.grandBilled,
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                  _SummaryStatCard(
                    label: 'Grand Advances',
                    value: data.grandAdvances,
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFFD97706), // Amber 600
                  ),
                  _SummaryStatCard(
                    label: 'Grand Balance',
                    value: data.grandBalance,
                    icon: Icons.savings_outlined,
                    color: data.grandBalance >= 0 ? AppColors.success : AppColors.error,
                  ),
                ];

                if (!isWide) {
                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        cards[i],
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Client Groups
            if (data.groups.isEmpty)
              _EmptyBillingState(filter: prov.filter)
            else
              for (final g in data.groups) ...[
                _ClientBillingCard(
                  group: g,
                  readOnly: data.readOnly,
                  onEditBilling: (task) => _showEditBillingDialog(context, prov, authProv, task),
                ),
                const SizedBox(height: 20),
              ],
          ],
        ),
      ),
    );
  }

  void _showEditBillingDialog(
    BuildContext context,
    BillingProvider prov,
    AuthProvider authProv,
    BillingTaskRow task,
  ) {
    final billAmountCtrl = TextEditingController(
      text: (task.billAmount != null && task.billAmount! > 0) ? task.billAmount!.toStringAsFixed(2) : '',
    );
    final advanceAmountCtrl = TextEditingController();
    final advanceNoteCtrl = TextEditingController();
    bool isBilled = task.billed;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: adaptiveAccentColor(dialogCtx, AppColors.primary), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Billing — #${task.id}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.description,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dialogCtx.adaptiveSlate900),
                    ),
                    if (task.client != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Client: ${task.client}',
                        style: TextStyle(fontSize: 12, color: dialogCtx.adaptiveSlate500),
                      ),
                    ],
                    const Divider(height: 24),

                    // Bill Amount Input
                    TextField(
                      controller: billAmountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bill Amount (\u20b9)',
                        hintText: 'e.g. 5000',
                        prefixText: '\u20b9 ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // Billed Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mark as Billed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Includes this task in completed client invoices', style: TextStyle(fontSize: 12)),
                      value: isBilled,
                      activeThumbColor: adaptiveAccentColor(dialogCtx, AppColors.primary),
                      onChanged: (val) {
                        setStateDialog(() => isBilled = val);
                      },
                    ),

                    const Divider(height: 24),

                    // Add Advance (Optional)
                    Text(
                      'Record Advance (Optional)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: dialogCtx.adaptiveSlate700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: advanceAmountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Advance Amount (\u20b9)',
                        hintText: 'e.g. 1000',
                        prefixText: '\u20b9 ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: advanceNoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Advance Note / Reference',
                        hintText: 'e.g. Received via GPay',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final billVal = num.tryParse(billAmountCtrl.text.trim()) ?? 0;
                        final advVal = num.tryParse(advanceAmountCtrl.text.trim());
                        final advNote = advanceNoteCtrl.text.trim().isEmpty ? null : advanceNoteCtrl.text.trim();

                        setStateDialog(() => isSubmitting = true);
                        try {
                          await prov.updateTaskBilling(
                            task.id,
                            billAmount: billVal,
                            billed: isBilled,
                            newAdvanceAmount: advVal,
                            newAdvanceNote: advNote,
                            currentUserId: authProv.user?.id,
                            currentUserName: authProv.user?.name,
                          );
                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          if (context.mounted) showSavedSnack(context, message: 'Billing updated \u2713');
                        } catch (e) {
                          if (context.mounted) showSavedSnack(context, ok: false, message: e.toString());
                        } finally {
                          if (dialogCtx.mounted) setStateDialog(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Billing'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final String currentFilter;
  final int totalCount;
  final int billedCount;
  final int unbilledCount;
  final ValueChanged<String> onFilterChanged;

  const _FilterTabs({
    required this.currentFilter,
    required this.totalCount,
    required this.billedCount,
    required this.unbilledCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.isDarkMode ? Colors.white.withValues(alpha: 0.06) : AppColors.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 6,
        children: [
          _TabPill(
            label: 'All ($totalCount)',
            selected: currentFilter == 'all',
            onTap: () => onFilterChanged('all'),
          ),
          _TabPill(
            label: 'Billed ($billedCount)',
            selected: currentFilter == 'billed',
            onTap: () => onFilterChanged('billed'),
          ),
          _TabPill(
            label: 'Pending Billing ($unbilledCount)',
            selected: currentFilter == 'unbilled',
            onTap: () => onFilterChanged('unbilled'),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final activeBg = isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white;
    return Material(
      color: selected ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: (selected && !isDark) ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? adaptiveAccentColor(context, AppColors.primary) : context.adaptiveSlate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final effectiveColor = adaptiveAccentColor(context, color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.adaptiveBorder),
        boxShadow: isDark ? null : AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: effectiveColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.adaptiveSlate500),
                ),
                const SizedBox(height: 2),
                Text(
                  fmtMoney(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.adaptiveSlate900,
                    letterSpacing: -0.3,
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

class _ClientBillingCard extends StatelessWidget {
  final BillingGroup group;
  final bool readOnly;
  final ValueChanged<BillingTaskRow> onEditBilling;

  const _ClientBillingCard({
    required this.group,
    required this.readOnly,
    required this.onEditBilling,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final successColor = isDark ? const Color(0xFF34D399) : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.adaptiveBorder),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header with client name & financial pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: adaptiveAccentColor(context, AppColors.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.client,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.adaptiveSlate900),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: context.adaptiveSlate100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.adaptiveBorder),
                  ),
                  child: Text(
                    'Billed ${fmtMoney(group.billed)}  \u2022  Advances ${fmtMoney(group.advances)}  \u2022  Balance ${fmtMoney(group.balance)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.adaptiveSlate700),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.adaptiveBorder),

          // Horizontal scrollable table container (scrolls ONLY if table overflows card)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(context.adaptiveSlate100),
              headingTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.adaptiveSlate800),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              horizontalMargin: 16,
              columnSpacing: 24,
              columns: [
                const DataColumn(label: Text('Task')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Billing')),
                const DataColumn(label: Text('Bill amount')),
                const DataColumn(label: Text('Advances')),
                const DataColumn(label: Text('Balance')),
                const DataColumn(label: Text('Completed')),
                if (!readOnly) const DataColumn(label: Text('Actions')),
              ],
              rows: [
                for (final t in group.tasks)
                  DataRow(
                    cells: [
                      // Task Description
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: InkWell(
                            onTap: () => context.push('/dev-crm/tasks/${t.id}'),
                            child: Tooltip(
                              message: '${t.description}\n(Tap to view task)',
                              waitDuration: const Duration(milliseconds: 250),
                              child: Text(
                                t.description,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(fontSize: 13, color: context.adaptiveSlate800, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Task Status
                      DataCell(StatusChip(status: t.status)),
                      // Billed Badge
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.billed
                                ? successColor.withValues(alpha: 0.14)
                                : context.adaptiveSlate200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: t.billed ? successColor.withValues(alpha: 0.35) : context.adaptiveBorder,
                            ),
                          ),
                          child: Text(
                            t.billed ? 'Billed' : 'Unbilled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.billed ? successColor : context.adaptiveSlate600,
                            ),
                          ),
                        ),
                      ),
                      // Bill Amount
                      DataCell(
                        Text(
                          fmtMoney(t.billAmount),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.adaptiveSlate900),
                        ),
                      ),
                      // Advances
                      DataCell(
                        Text(
                          fmtMoney(t.advancesTotal),
                          style: TextStyle(fontSize: 13, color: context.adaptiveSlate700),
                        ),
                      ),
                      // Balance
                      DataCell(
                        Text(
                          fmtMoney(t.balance),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.balance > 0 ? context.adaptiveSlate900 : context.adaptiveSlate500,
                          ),
                        ),
                      ),
                      // Completed Date
                      DataCell(
                        Text(
                          t.completedAt == null ? '-' : fmtDateTimeIst(t.completedAt),
                          style: TextStyle(fontSize: 12.5, color: context.adaptiveSlate600),
                        ),
                      ),
                      // Actions (Edit Billing)
                      if (!readOnly)
                        DataCell(
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit', style: TextStyle(fontSize: 12)),
                            onPressed: () => onEditBilling(t),
                          ),
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

class _EmptyBillingState extends StatelessWidget {
  final String filter;
  const _EmptyBillingState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = adaptiveAccentColor(context, AppColors.primary);
    final message = filter == 'billed'
        ? 'No billed tasks found.'
        : filter == 'unbilled'
            ? 'No unbilled completed tasks found.'
            : 'No billing records found.';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: context.adaptiveCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.adaptiveBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? accent.withValues(alpha: 0.18) : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_outlined, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: context.adaptiveSlate500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
